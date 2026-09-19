import 'dart:io';

import 'package:customer/core/domain/models/document_category.dart';
import 'package:customer/core/domain/models/document_model.dart';
import 'package:customer/core/domain/repositories/favorite_repository.dart';
import 'package:customer/core/domain/repositories/recent_repository.dart';
import 'package:customer/core/domain/usecase/usecase.dart';
import 'package:customer/core/presentation/controllers/document_interaction_controller.dart';
import 'package:customer/core/presentation/utils/state_status.dart';
import 'package:customer/features/text_reader/presentation/text_reader_controller.dart';
import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  ResultFuture<void> toggle(String documentId) async => const Right(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  Map<String, Object?> position = const {};
  int markOpenedCalls = 0;
  Map<String, Object?>? lastReadingPosition;

  @override
  ResultFuture<Map<String, Object?>> getPosition(String documentId) async => Right(position);

  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async {
    markOpenedCalls++;
    lastReadingPosition = readingPosition;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late DocumentModel document;
  late DocumentModel missingDocument;
  late FixtureRecents recents;
  late DocumentInteractionController interactions;
  late TextReaderController controller;

  DocumentModel makeDocument(String path, {int sizeBytes = 10}) => DocumentModel(
        id: path,
        path: path,
        displayName: p.basename(path),
        extension: 'txt',
        category: DocumentCategory.text,
        sizeBytes: sizeBytes,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );

  Future<TextReaderController> loaded(TextReaderController c) async {
    c.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return c;
  }

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-text-reader-');
    final file = File(p.join(root.path, 'notes.txt'));
    await file.writeAsString('line one\nline two has fox\nline three\nfox again here');

    document = makeDocument(file.path, sizeBytes: (await file.length()));
    missingDocument = makeDocument(p.join(root.path, 'missing.txt'));

    recents = FixtureRecents();
    interactions = DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: recents);
    controller = TextReaderController(document: document, recentRepository: recents, interactions: interactions);
  });

  tearDown(() async {
    Get.reset();
    await root.delete(recursive: true);
  });

  group('loading a real text file', () {
    test('decodes and splits into lines', () async {
      await loaded(controller);
      expect(controller.status.value, StateStatus.success);
      expect(controller.lines, ['line one', 'line two has fox', 'line three', 'fox again here']);
    });

    test('falls back to Latin-1 for non-UTF-8 bytes instead of failing', () async {
      final file = File(p.join(root.path, 'latin1.txt'));
      // 0xE9 is not valid standalone UTF-8 but decodes as 'é' under Latin-1.
      await file.writeAsBytes([0x63, 0x61, 0x66, 0xE9]);
      final latin1Document = makeDocument(file.path, sizeBytes: 4);
      final latin1Controller = TextReaderController(document: latin1Document, recentRepository: recents, interactions: interactions);
      await loaded(latin1Controller);
      expect(latin1Controller.status.value, StateStatus.success);
      expect(latin1Controller.lines.single, 'café');
    });

    test('treats a binary file renamed .txt as corrupted rather than rendering garbage', () async {
      final file = File(p.join(root.path, 'binary.txt'));
      await file.writeAsBytes(List<int>.generate(2000, (i) => i % 2 == 0 ? 0x00 : 0x01));
      final binaryDocument = makeDocument(file.path, sizeBytes: 2000);
      final binaryController = TextReaderController(document: binaryDocument, recentRepository: recents, interactions: interactions);
      await loaded(binaryController);
      expect(binaryController.status.value, StateStatus.error);
      expect(binaryController.errorMessage.value, 'This document may be damaged or incomplete.');
    });

    test('refuses a file larger than the size ceiling', () async {
      final file = File(p.join(root.path, 'huge.txt'));
      // 'A' repeated - plain, valid UTF-8 text; only its size matters here.
      await file.writeAsBytes(List<int>.filled(TextReaderController.maxBytes + 1, 0x41));
      final hugeDocument = makeDocument(file.path, sizeBytes: TextReaderController.maxBytes + 1);
      final hugeController = TextReaderController(document: hugeDocument, recentRepository: recents, interactions: interactions);
      await loaded(hugeController);
      expect(hugeController.status.value, StateStatus.error);
      expect(hugeController.errorMessage.value, 'This document is too large to render safely on this device.');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('initial position restore', () {
    test('defaults to no scroll offset when nothing is stored', () async {
      await loaded(controller);
      expect(controller.initialScrollOffset, 0);
    });

    test('restores a saved scroll offset', () async {
      recents.position = {'scroll_offset': 88.0};
      await loaded(controller);
      expect(controller.initialScrollOffset, 88.0);
    });
  });

  group('reading position persistence', () {
    test('onScrolled saves after a 2 second debounce', () {
      fakeAsync((async) {
        controller.onScrolled(40);
        expect(recents.markOpenedCalls, 0);
        async.elapse(const Duration(seconds: 2, milliseconds: 1));
        expect(recents.markOpenedCalls, 1);
        expect(recents.lastReadingPosition, {'scroll_offset': 40.0});
      });
    });

    test('onClose is a no-op when the reader was never scrolled', () {
      expect(controller.onClose, returnsNormally);
      expect(recents.markOpenedCalls, 0);
    });
  });

  group('search', () {
    test('finds matching lines case-insensitively and jumps to the first', () async {
      await loaded(controller);
      controller.search('fox');
      expect(controller.matches, [1, 3]);
      expect(controller.currentMatchIndex.value, 0);
    });

    test('goToNextMatch/goToPrevMatch wrap around', () async {
      await loaded(controller);
      controller.search('fox');
      controller.goToNextMatch();
      expect(controller.currentMatchIndex.value, 1);
      controller.goToNextMatch();
      expect(controller.currentMatchIndex.value, 0);
      controller.goToPrevMatch();
      expect(controller.currentMatchIndex.value, 1);
    });

    test('an empty query clears matches', () async {
      await loaded(controller);
      controller.search('fox');
      controller.search('');
      expect(controller.matches, isEmpty);
      expect(controller.currentMatchIndex.value, -1);
    });
  });

  group('display preferences', () {
    test('increaseFontSize/decreaseFontSize clamp to a sane range', () {
      expect(controller.fontSize.value, 14.0);
      for (var i = 0; i < 20; i++) {
        controller.increaseFontSize();
      }
      expect(controller.fontSize.value, 32.0);
      for (var i = 0; i < 20; i++) {
        controller.decreaseFontSize();
      }
      expect(controller.fontSize.value, 10.0);
    });

    test('toggleLineWrap flips the flag', () {
      expect(controller.lineWrap.value, isTrue);
      controller.toggleLineWrap();
      expect(controller.lineWrap.value, isFalse);
    });
  });

  group('delegation to DocumentInteractionController', () {
    test('isFavorite / toggleFavorite delegate to the shared interaction controller', () async {
      expect(controller.isFavorite, isFalse);
      await controller.toggleFavorite();
      expect(controller.isFavorite, isTrue);
    });

    testWidgets('share blocks on a missing file before reaching the share sheet', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = TextReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.share();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('openWith blocks on a missing file before reaching the chooser', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = TextReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.openWith();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
