import 'dart:io';
import 'dart:typed_data';

import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/core/presentation/utils/zip_safety_guard.dart';
import 'package:openreader/core/presentation/widgets/cell_grid/cell_grid.dart';
import 'package:openreader/core/presentation/widgets/cell_grid/cell_grid_controller.dart';
import 'package:openreader/features/excel_reader/presentation/excel_reader_controller.dart';
import 'package:archive/archive.dart';
import 'package:dartz/dartz.dart';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // Poll instead of a fixed delay: real file I/O latency varies under load.
    for (var i = 0; i < 100 && c.status.value.isBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return c;
  }

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-excel-reader-');

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

    test('leaves out sheets the author hid, as Excel does', () async {
      final workbook = xls.Excel.createExcel();
      final first = workbook.getDefaultSheet()!;
      workbook[first].cell(xls.CellIndex.indexByString('A1')).value = xls.TextCellValue('shown');
      workbook['Secret'].cell(xls.CellIndex.indexByString('A1')).value = xls.TextCellValue('hidden');
      workbook['Secret'].visibility = xls.SheetVisibility.hidden;
      workbook['Later'].cell(xls.CellIndex.indexByString('A1')).value = xls.TextCellValue('shown too');
      final file = File(p.join(root.path, 'hidden.xlsx'));
      await file.writeAsBytes(workbook.encode()!);
      final c = ExcelReaderController(
        document: DocumentModel(
          id: file.path,
          path: file.path,
          displayName: 'hidden.xlsx',
          extension: 'xlsx',
          category: DocumentCategory.excel,
          sizeBytes: 1,
          modifiedAt: DateTime(2026),
          lastSeenAt: DateTime(2026),
        ),
        recentRepository: recents,
        interactions: interactions,
      );
      await loaded(c);
      expect(c.sheetNames, [first, 'Later']);
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

    // ODF-P5-04: a real password-protected .xlsx isn't a ZIP at all - Office
    // wraps the whole package in an OLE2 compound file (`EncryptedPackage`/
    // `EncryptionInfo` streams). This fixture reproduces that exact 8-byte
    // OLE2 signature (no real encryption needed to verify the fallback path,
    // since the file is provably not ZIP-shaped either way) and asserts it
    // fails gracefully through the same existing generic message, not a
    // crash or hang.
    test('surfaces the generic corrupted-file error for an OLE2-wrapped (password-protected-shaped) file', () async {
      final encryptedFile = File(p.join(root.path, 'protected.xlsx'));
      await encryptedFile.writeAsBytes([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, ...List.filled(504, 0)]);
      final encryptedDocument = DocumentModel(
        id: encryptedFile.path,
        path: encryptedFile.path,
        displayName: 'protected.xlsx',
        extension: 'xlsx',
        category: DocumentCategory.excel,
        sizeBytes: 512,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );
      final encryptedController = ExcelReaderController(document: encryptedDocument, recentRepository: recents, interactions: interactions);
      await loaded(encryptedController);
      expect(encryptedController.status.value, StateStatus.error);
      expect(encryptedController.errorMessage.value, 'This document may be damaged or incomplete.');
    });

    // ODF-P5-03: the ZIP-safety guard rejects an oversized declared
    // uncompressed size before `excel_plus` ever decompresses it.
    test('surfaces the too-large error for a workbook exceeding the ZIP-safety ceiling', () async {
      final archive = Archive()
        ..addFile(ArchiveFile(
          'huge.bin',
          ZipSafetyGuard.maxUncompressedBytes + 1,
          Uint8List(0),
        ));
      final oversizedFile = File(p.join(root.path, 'huge.xlsx'));
      await oversizedFile.writeAsBytes(ZipEncoder().encode(archive));
      final oversizedDocument = DocumentModel(
        id: oversizedFile.path,
        path: oversizedFile.path,
        displayName: 'huge.xlsx',
        extension: 'xlsx',
        category: DocumentCategory.excel,
        sizeBytes: await oversizedFile.length(),
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );
      final oversizedController = ExcelReaderController(document: oversizedDocument, recentRepository: recents, interactions: interactions);
      await loaded(oversizedController);
      expect(oversizedController.status.value, StateStatus.error);
      expect(oversizedController.errorMessage.value, 'This document is too large to render safely on this device.');
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

    test('onClose with detached scroll views keeps the restored offsets, not zero (P2r1-review #2)', () async {
      recents.position = {'sheet_index': 0, 'vertical_offset': 300.0, 'horizontal_offset': 120.0};
      await loaded(controller);
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.lastReadingPosition?['vertical_offset'], 300.0);
      expect(recents.lastReadingPosition?['horizontal_offset'], 120.0);
    });

    test('re-selecting the current sheet keeps its offsets (P2r3-review #1)', () async {
      recents.position = {'sheet_index': 0, 'vertical_offset': 5000.0, 'horizontal_offset': 400.0};
      await loaded(controller);
      controller.switchSheet(0);
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.lastReadingPosition?['vertical_offset'], 5000.0);
      expect(recents.lastReadingPosition?['horizontal_offset'], 400.0);
    });

    test('a quick close after a sheet switch saves the new sheet at the top (P2r2-review #1)', () async {
      recents.position = {'sheet_index': 0, 'vertical_offset': 5000.0, 'horizontal_offset': 400.0};
      await loaded(controller);
      controller.switchSheet(1);
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.lastReadingPosition, {
        'sheet_index': 1,
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

  group('grid zoom and cell detail (UX-32)', () {
    test('zoom steps stay within 75%-200%', () {
      expect(controller.zoom.value, 1.0);
      for (var i = 0; i < 10; i++) {
        controller.zoomIn();
      }
      expect(controller.zoom.value, CellGridZoom.maxZoom);
      expect(controller.canZoomIn, isFalse);
      for (var i = 0; i < 10; i++) {
        controller.zoomOut();
      }
      expect(controller.zoom.value, CellGridZoom.minZoom);
      expect(controller.canZoomOut, isFalse);
    });

    testWidgets('tapping a cell shows its full value with Copy; zoom scales cells', (tester) async {
      await tester.runAsync(() => loaded(controller));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CellGrid(controller: controller))));
      await tester.pump();
      Finder cellOf(String text) => find.ancestor(of: find.text(text), matching: find.byType(Container)).first;
      expect(tester.getSize(cellOf('Alice')).width, CellGridController.cellWidth);

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(find.text('Cell A2'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Copy'), findsOneWidget);
      Navigator.of(tester.element(find.text('Cell A2'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);
      expect(tester.getSize(cellOf('Alice')).width, CellGridController.cellWidth * 1.25);
    });

    testWidgets('tapping a column or row header selects it, sums its numbers, copies it, and clears', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.runAsync(() => loaded(controller));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CellGrid(controller: controller))));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Column B'));
      await tester.pump();
      // 'Score' is text, so only 97 counts toward Sum/Average.
      expect(find.textContaining('Count 2 · Sum 97 · Avg 97'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy column b'));
      await tester.pump();
      expect(copied, 'Score\n97');
      expect(find.text('Column B copied'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Row 2'));
      await tester.pump();
      expect(find.byTooltip('Copy row 2'), findsOneWidget);
      expect(find.byTooltip('Copy column b'), findsNothing);

      // Tapping the selected header again clears it.
      await tester.tap(find.bySemanticsLabel('Row 2'));
      await tester.pump();
      expect(find.byTooltip('Clear selection'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
