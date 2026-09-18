import 'dart:io';

import 'package:customer/core/domain/models/document_category.dart';
import 'package:customer/core/domain/models/document_model.dart';
import 'package:customer/core/domain/repositories/favorite_repository.dart';
import 'package:customer/core/domain/repositories/recent_repository.dart';
import 'package:customer/core/domain/usecase/usecase.dart';
import 'package:customer/core/presentation/controllers/document_interaction_controller.dart';
import 'package:customer/core/presentation/utils/state_status.dart';
import 'package:customer/features/excel_reader/presentation/excel_reader_controller.dart';
import 'package:dartz/dartz.dart';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

// excel_plus is a pure-Dart parser with no native binary dependency (unlike
// pdfrx's PDFium), so a real .xlsx workbook can be built, encoded, and
// re-parsed end to end in this test environment - unlike the PDF reader,
// whose native rendering stays an out-of-environment gap.

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
  late ExcelReaderController controller;

  Future<ExcelReaderController> loaded(ExcelReaderController c) async {
    c.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return c;
  }

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('opendocs-excel-reader-');

    final workbook = xls.Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet()!;
    final summary = workbook[defaultSheetName];
    summary.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xls.TextCellValue('Name');
    summary.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = xls.TextCellValue('Score');
    summary.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xls.TextCellValue('Alice');
    summary.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = const xls.IntCellValue(97);
    workbook.rename(defaultSheetName, 'Summary');
    workbook['April'].cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xls.TextCellValue('April data');

    final bytes = workbook.encode()!;
    final file = File(p.join(root.path, 'budget.xlsx'));
    await file.writeAsBytes(bytes);

    document = DocumentModel(
      id: file.path,
      path: file.path,
      displayName: 'budget.xlsx',
      extension: 'xlsx',
      category: DocumentCategory.excel,
      sizeBytes: bytes.length,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );
    missingDocument = DocumentModel(
      id: p.join(root.path, 'missing.xlsx'),
      path: p.join(root.path, 'missing.xlsx'),
      displayName: 'missing.xlsx',
      extension: 'xlsx',
      category: DocumentCategory.excel,
      sizeBytes: 10,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

    recents = FixtureRecents();
    interactions = DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: recents);
    controller = ExcelReaderController(document: document, recentRepository: recents, interactions: interactions);
  });

  tearDown(() async {
    Get.reset();
    await root.delete(recursive: true);
  });

  group('loading a real workbook', () {
    test('parses sheet names and cell values', () async {
      await loaded(controller);
      expect(controller.status.value, StateStatus.success);
      expect(controller.sheetNames, ['Summary', 'April']);
      expect(controller.currentRows[0][0]?.displayText, 'Name');
      expect(controller.currentRows[1][0]?.displayText, 'Alice');
      expect(controller.currentRows[1][1]?.displayText, '97');
    });

    test('restores the saved sheet index', () async {
      recents.position = {'sheet_index': 1};
      await loaded(controller);
      expect(controller.activeSheetIndex.value, 1);
      expect(controller.currentRows[0][0]?.displayText, 'April data');
    });

    test('restores saved scroll offsets for later use by the view', () async {
      recents.position = {'vertical_offset': 72.0, 'horizontal_offset': 220.0};
      await loaded(controller);
      expect(controller.initialVerticalOffset, 72.0);
      expect(controller.initialHorizontalOffset, 220.0);
    });

    test('surfaces the generic corrupted-file error for unreadable bytes', () async {
      final badFile = File(p.join(root.path, 'bad.xlsx'));
      await badFile.writeAsBytes([1, 2, 3, 4]);
      final badDocument = DocumentModel(
        id: badFile.path,
        path: badFile.path,
        displayName: 'bad.xlsx',
        extension: 'xlsx',
        category: DocumentCategory.excel,
        sizeBytes: 4,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );
      final badController = ExcelReaderController(document: badDocument, recentRepository: recents, interactions: interactions);
      await loaded(badController);
      expect(badController.status.value, StateStatus.error);
      expect(badController.errorMessage.value, 'This document may be damaged or incomplete.');
    });
  });

  group('sheet switching', () {
    test('switchSheet updates activeSheetIndex and clears an active search', () async {
      await loaded(controller);
      controller.search('Alice');
      expect(controller.matches, isNotEmpty);

      controller.switchSheet(1);
      expect(controller.activeSheetIndex.value, 1);
      expect(controller.matches, isEmpty);
      expect(controller.isSearching.value, isFalse);
    });

    test('switchSheet ignores an out-of-range index', () async {
      await loaded(controller);
      controller.switchSheet(99);
      expect(controller.activeSheetIndex.value, 0);
    });
  });

  group('cell search (ODF-016)', () {
    test('finds matching cells case-insensitively', () async {
      await loaded(controller);
      controller.search('alice');
      expect(controller.matches.length, 1);
      expect(controller.matches.first.row, 1);
      expect(controller.matches.first.column, 0);
      expect(controller.currentMatchIndex.value, 0);
    });

    test('an empty query clears matches', () async {
      await loaded(controller);
      controller.search('Alice');
      controller.search('');
      expect(controller.matches, isEmpty);
      expect(controller.currentMatchIndex.value, -1);
    });

    test('goToNextMatch/goToPrevMatch wrap around', () async {
      await loaded(controller);
      controller.search('a'); // matches multiple cells case-insensitively
      final count = controller.matches.length;
      expect(count, greaterThan(1));

      controller.goToPrevMatch();
      expect(controller.currentMatchIndex.value, count - 1);

      for (var i = 0; i < count; i++) {
        controller.goToNextMatch();
      }
      expect(controller.currentMatchIndex.value, count - 1);
    });
  });

  group('reading position persistence', () {
    test('onClose is safe and no-ops when the workbook never finished loading', () {
      expect(controller.onClose, returnsNormally);
      expect(recents.markOpenedCalls, 0);
    });

    test('onClose persists a position once loaded, defaulting offsets to zero with no attached scroll views', () async {
      await loaded(controller);
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.markOpenedCalls, 1);
      expect(recents.lastReadingPosition, {
        'sheet_index': 0,
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
      final missingController = ExcelReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.share();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('openWith blocks on a missing file before reaching the chooser', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = ExcelReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.openWith();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
