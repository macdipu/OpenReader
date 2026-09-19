import 'dart:io';

import 'package:customer/core/domain/models/document_category.dart';
import 'package:customer/core/domain/models/document_model.dart';
import 'package:customer/core/domain/repositories/favorite_repository.dart';
import 'package:customer/core/domain/repositories/recent_repository.dart';
import 'package:customer/core/domain/usecase/usecase.dart';
import 'package:customer/core/presentation/controllers/document_interaction_controller.dart';
import 'package:customer/core/presentation/utils/state_status.dart';
import 'package:customer/features/csv_reader/presentation/csv_reader_controller.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

// excel_plus's CSV parsing is pure Dart with no native binary dependency, so
// a real .csv file - including one exercising BRD's own hard corner cases
// (quoted commas, multi-line quoted values) - can be built and parsed end to
// end in this test environment.

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
  late CsvReaderController controller;

  DocumentModel makeDocument(String path, {int sizeBytes = 10}) => DocumentModel(
        id: path,
        path: path,
        displayName: p.basename(path),
        extension: 'csv',
        category: DocumentCategory.csv,
        sizeBytes: sizeBytes,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );

  Future<CsvReaderController> loaded(CsvReaderController c) async {
    c.onInit();
    // Parsing runs on a real background Isolate (see CsvReaderController's
    // own doc comment on why), which has real spin-up latency unlike a
    // fixture Future - poll instead of a single fixed delay.
    for (var i = 0; i < 100 && c.status.value.isBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return c;
  }

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-csv-reader-');
    final file = File(p.join(root.path, 'budget.csv'));
    // Includes BRD's own hard corner cases: a quoted value containing a
    // comma, and a quoted value spanning multiple lines.
    await file.writeAsString('Name,Note,Score\n"Doe, Jane","Great\nwork",97\nAlice,Fine,88\n');

    document = makeDocument(file.path, sizeBytes: (await file.length()));
    missingDocument = makeDocument(p.join(root.path, 'missing.csv'));

    recents = FixtureRecents();
    interactions = DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: recents);
    controller = CsvReaderController(document: document, recentRepository: recents, interactions: interactions);
  });

  tearDown(() async {
    Get.reset();
    await root.delete(recursive: true);
  });

  group('loading a real CSV file', () {
    test('parses rows, honoring quoted commas and multi-line quoted values', () async {
      await loaded(controller);
      expect(controller.status.value, StateStatus.success);
      expect(controller.currentRows[0][0]?.displayText, 'Name');
      expect(controller.currentRows[1][0]?.displayText, 'Doe, Jane');
      expect(controller.currentRows[1][1]?.displayText, 'Great\nwork');
      expect(controller.currentRows[2][0]?.displayText, 'Alice');
    });

    test('surfaces the generic corrupted-file error when parsing throws', () async {
      // excel_plus's CSV import is permissive about content, so a genuinely
      // unparseable case here is an unreadable file rather than malformed
      // text - a directory path is the simplest way to force a real read
      // failure without depending on excel_plus's exact validation rules.
      final dirDocument = makeDocument(root.path);
      final dirController = CsvReaderController(document: dirDocument, recentRepository: recents, interactions: interactions);
      await loaded(dirController);
      expect(dirController.status.value, StateStatus.error);
      expect(dirController.errorMessage.value, 'This document may be damaged or incomplete.');
    });

    test('refuses a file larger than the size ceiling', () async {
      final file = File(p.join(root.path, 'huge.csv'));
      await file.writeAsBytes(List<int>.filled(CsvReaderController.maxBytes + 1, 0x2C)); // ','
      final hugeDocument = makeDocument(file.path, sizeBytes: CsvReaderController.maxBytes + 1);
      final hugeController = CsvReaderController(document: hugeDocument, recentRepository: recents, interactions: interactions);
      await loaded(hugeController);
      expect(hugeController.status.value, StateStatus.error);
      expect(hugeController.errorMessage.value, 'This document is too large to render safely on this device.');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('initial position restore', () {
    test('restores saved scroll offsets for later use by the view', () async {
      recents.position = {'vertical_offset': 40.0, 'horizontal_offset': 60.0};
      await loaded(controller);
      expect(controller.initialVerticalOffset, 40.0);
      expect(controller.initialHorizontalOffset, 60.0);
    });
  });

  group('cell search (ODF-020)', () {
    test('finds matching cells case-insensitively', () async {
      await loaded(controller);
      controller.search('alice');
      expect(controller.matches.length, 1);
      expect(controller.matches.first.row, 2);
      expect(controller.matches.first.column, 0);
    });

    test('an empty query clears matches', () async {
      await loaded(controller);
      controller.search('Alice');
      controller.search('');
      expect(controller.matches, isEmpty);
      expect(controller.currentMatchIndex.value, -1);
    });
  });

  group('reading position persistence', () {
    test('onClose is safe and no-ops when the file never finished loading', () {
      expect(controller.onClose, returnsNormally);
      expect(recents.markOpenedCalls, 0);
    });

    test('onClose persists a position once loaded', () async {
      await loaded(controller);
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.markOpenedCalls, 1);
      expect(recents.lastReadingPosition, {
        'row': 0,
        'column': 0,
        'vertical_offset': 0.0,
        'horizontal_offset': 0.0,
      });
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
      final missingController = CsvReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.share();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('openWith blocks on a missing file before reaching the chooser', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = CsvReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.openWith();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
