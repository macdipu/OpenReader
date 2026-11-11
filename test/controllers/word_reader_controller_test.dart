// These tests stand in for the package's views, reporting scrolls the way
// they do, through members the package marks internal.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';
import 'dart:typed_data';

import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';
import 'package:openreader/features/word_reader/presentation/word_reader_controller.dart';
import 'package:archive/archive.dart';
import 'package:dartz/dartz.dart';
import 'package:universal_document_viewer/testing.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/temp_dir.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

// universal_document_viewer's Word engine is pure Dart with no native binary (unlike
// PDFium), so - unlike the PDF reader - a real .docx file can be built and
// parsed in this test environment. These tests build one in setUp
// (`buildDocx`) and use it throughout.

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
  late WordReaderController controller;

  Future<WordReaderController> loaded(WordReaderController c) async {
    c.onInit();
    // Poll instead of a fixed delay: real file I/O latency varies under load.
    for (var i = 0; i < 100 && c.status.value.isBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return c;
  }

  setUpAll(() async {
    // The kit's controller uses the binding (scroll controllers); keep it
    // available outside widget tests.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-word-reader-');

    final bytes = buildDocx(
      '<w:p><w:r><w:t>Report Title</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>The quick brown fox jumps over the lazy dog.</w:t></w:r></w:p>',
    );
    final file = File(p.join(root.path, 'report.docx'));
    await file.writeAsBytes(bytes);

    document = DocumentModel(
      id: file.path,
      path: file.path,
      displayName: 'report.docx',
      extension: 'docx',
      category: DocumentCategory.word,
      sizeBytes: bytes.length,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );
    missingDocument = DocumentModel(
      id: p.join(root.path, 'missing.docx'),
      path: p.join(root.path, 'missing.docx'),
      displayName: 'missing.docx',
      extension: 'docx',
      category: DocumentCategory.word,
      sizeBytes: 10,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

    recents = FixtureRecents();
    interactions = DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: recents);
    controller = WordReaderController(document: document, recentRepository: recents, interactions: interactions);
  });

  tearDown(() async {
    Get.reset();
    await deleteTempDir(root);
  });

  group('initial position restore', () {
    test('defaults to no scroll offset when nothing is stored', () async {
      await loaded(controller);
      expect(controller.initialScrollOffset, 0);
    });

    test('restores a saved scroll offset', () async {
      recents.position = {'scroll_offset': 250.5};
      await loaded(controller);
      expect(controller.initialScrollOffset, 250.5);
    });

    test('ignores a non-positive or malformed scroll_offset', () async {
      recents.position = {'scroll_offset': -5};
      await loaded(controller);
      expect(controller.initialScrollOffset, 0);
    });
  });

  group('reading position persistence', () {
    test('a scroll saves after a 2 second debounce', () {
      fakeAsync((async) {
        controller.word.onScrollOffsetChanged(120);
        expect(recents.markOpenedCalls, 0);
        async.elapse(const Duration(seconds: 1));
        expect(recents.markOpenedCalls, 0);
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        expect(recents.markOpenedCalls, 1);
        expect(recents.lastReadingPosition, {'scroll_offset': 120.0, 'view_mode': 'continuous'});
      });
    });

    test('a later scroll resets the debounce; only the latest offset is saved', () {
      fakeAsync((async) {
        controller.word.onScrollOffsetChanged(50);
        async.elapse(const Duration(seconds: 1));
        controller.word.onScrollOffsetChanged(90);
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        expect(recents.markOpenedCalls, 0);
        async.elapse(const Duration(seconds: 1));
        expect(recents.markOpenedCalls, 1);
        expect(recents.lastReadingPosition, {'scroll_offset': 90.0, 'view_mode': 'continuous'});
      });
    });

    test('restores print layout with its offset, and the menu toggles layout', () async {
      recents.position = {'scroll_offset': 300.0, 'view_mode': 'paged'};
      await loaded(controller);
      expect(controller.isPaged.value, isTrue);
      expect(controller.initialScrollOffset, 300.0);
      controller.toggleLayout();
      expect(controller.isPaged.value, isFalse);
    });

    test('onClose is a no-op when the document was never scrolled', () {
      expect(controller.onClose, returnsNormally);
      expect(recents.markOpenedCalls, 0);
    });

    test('onClose persists the last known scroll offset', () async {
      controller.word.onScrollOffsetChanged(75);
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.markOpenedCalls, 1);
      expect(recents.lastReadingPosition, {'scroll_offset': 75.0, 'view_mode': 'continuous'});
    });
  });

  group('search', () {
    test('startSearching/stopSearching toggle state and clear the search controller', () {
      controller.startSearching();
      expect(controller.isSearching.value, isTrue);

      controller.onSearchQueryChanged('fox');
      expect(controller.word.searchState.value.query, 'fox');

      controller.stopSearching();
      expect(controller.isSearching.value, isFalse);
      expect(controller.word.searchState.value.query, '');
    });
  });

  group('error handling', () {
    test('a failed load flips hasError', () {
      expect(controller.hasError.value, isFalse);
      controller.word.markFailed(DocumentLoadError.corrupted);
      expect(controller.hasError.value, isTrue);
    });

    test('closing while the file is still being read leaves the disposed document alone', () async {
      final missingController =
          WordReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      missingController.onInit();
      missingController.onClose();
      // The read fails after the close; reporting it would notify a disposed controller.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(missingController.hasError.value, isFalse);
    });

    test('a valid docx passes the ZIP-safety guard and is parsed', () async {
      await loaded(controller);
      expect(controller.hasError.value, isFalse);
      expect(controller.word.document, isNotNull);
    });

    // ODF-P5-04: a real password-protected .docx isn't a ZIP at all - Office
    // wraps the whole package in an OLE2 compound file (`EncryptedPackage`/
    // `EncryptionInfo` streams). This fixture reproduces that exact 8-byte
    // OLE2 signature (no real encryption needed to verify the fallback path,
    // since the file is provably not ZIP-shaped either way) and asserts it
    // fails gracefully through the same existing generic message, not a
    // crash or hang.
    test('surfaces the generic corrupted-file error for an OLE2-wrapped (password-protected-shaped) file', () async {
      final encryptedFile = File(p.join(root.path, 'protected.docx'));
      await encryptedFile.writeAsBytes([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, ...List.filled(504, 0)]);
      final encryptedDocument = DocumentModel(
        id: encryptedFile.path,
        path: encryptedFile.path,
        displayName: 'protected.docx',
        extension: 'docx',
        category: DocumentCategory.word,
        sizeBytes: 512,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );
      final encryptedController = WordReaderController(document: encryptedDocument, recentRepository: recents, interactions: interactions);
      await loaded(encryptedController);
      expect(encryptedController.hasError.value, isTrue);
      expect(encryptedController.errorMessage.value, 'This document may be damaged or incomplete.');
      expect(encryptedController.word.document, isNull);
    });

    // ODF-P5-03: the ZIP-safety guard rejects an oversized declared
    // uncompressed size before the Word engine ever decompresses it.
    test('surfaces the too-large error for a document exceeding the ZIP-safety ceiling', () async {
      final archive = Archive()
        ..addFile(ArchiveFile(
          'huge.bin',
          ZipSafetyGuard.maxUncompressedBytes + 1,
          Uint8List(0),
        ));
      final oversizedFile = File(p.join(root.path, 'huge.docx'));
      await oversizedFile.writeAsBytes(ZipEncoder().encode(archive));
      final oversizedDocument = DocumentModel(
        id: oversizedFile.path,
        path: oversizedFile.path,
        displayName: 'huge.docx',
        extension: 'docx',
        category: DocumentCategory.word,
        sizeBytes: await oversizedFile.length(),
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );
      final oversizedController = WordReaderController(document: oversizedDocument, recentRepository: recents, interactions: interactions);
      await loaded(oversizedController);
      expect(oversizedController.hasError.value, isTrue);
      expect(oversizedController.errorMessage.value, 'This document is too large to render safely on this device.');
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
      final missingController = WordReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.share();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('openWith blocks on a missing file before reaching the chooser', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = WordReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.openWith();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  // Rendering is covered in universal_document_viewer's own widget tests
  // (word_document_view_test.dart), which pump the real view.
}
