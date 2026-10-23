import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_reader_kit/excel.dart' as xls;
import 'package:open_reader_kit/open_reader_kit.dart';
import 'package:open_reader_kit/sheets.dart';

void main() {
  Uint8List workbook() {
    final book = xls.Excel.createExcel();
    final first = book.getDefaultSheet()!;
    book[first].cell(xls.CellIndex.indexByString('A1')).value = xls.TextCellValue('Name');
    book[first].cell(xls.CellIndex.indexByString('A2')).value = xls.TextCellValue('Alice');
    book['Secret'].cell(xls.CellIndex.indexByString('A1')).value = xls.TextCellValue('hidden');
    book['Secret'].visibility = xls.SheetVisibility.hidden;
    book['Later'].cell(xls.CellIndex.indexByString('B3')).value = xls.TextCellValue('alice again');
    return Uint8List.fromList(book.encode()!);
  }

  test('loads an .xlsx, leaving out hidden sheets', () async {
    final sheet = SpreadsheetController();
    await sheet.loadXlsx(workbook());
    expect(sheet.error, isNull);
    expect(sheet.sheetNames.length, 2);
    expect(sheet.sheetNames, isNot(contains('Secret')));
    expect(sheet.currentRows[1][0]?.readerText, 'Alice');
  });

  test('restores the saved sheet and offsets', () async {
    final sheet = SpreadsheetController(initialPosition: {
      PositionKeys.sheetIndex: 1,
      PositionKeys.verticalOffset: 72.0,
      PositionKeys.horizontalOffset: 110.0,
    });
    await sheet.loadXlsx(workbook());
    expect(sheet.activeSheetIndex, 1);
    expect(sheet.initialVerticalOffset, 72);
    expect(sheet.initialHorizontalOffset, 110);
  });

  test('a saved sheet past the end falls back to the first', () async {
    final sheet = SpreadsheetController(initialPosition: {PositionKeys.sheetIndex: 7});
    await sheet.loadXlsx(workbook());
    expect(sheet.activeSheetIndex, 0);
  });

  test('loads CSV, including quoted commas and new lines', () {
    final sheet = SpreadsheetController()
      ..loadCsv(Uint8List.fromList(utf8.encode('Name,Note\n"Doe, Jane","two\nlines"\n')));
    expect(sheet.error, isNull);
    expect(sheet.currentRows[1][0]?.readerText, 'Doe, Jane');
    expect(sheet.currentRows[1][1]?.readerText, 'two\nlines');
  });

  test('typed errors', () async {
    final damaged = SpreadsheetController();
    await damaged.loadXlsx(Uint8List.fromList([1, 2, 3]));
    expect(damaged.error, DocumentLoadError.corrupted);
    expect((SpreadsheetController()..rejectAsTooLarge()).error, DocumentLoadError.tooLarge);
  });

  test('search is per sheet; switching sheets clears it and reports the position', () async {
    ReadingPosition? reported;
    final sheet = SpreadsheetController(onPositionChanged: (p) => reported = p);
    await sheet.loadXlsx(workbook());
    sheet.search('ALICE');
    expect(sheet.matches.map((m) => (m.row, m.column)), [(1, 0)]);
    sheet.switchSheet(1);
    expect(sheet.matches, isEmpty);
    expect(reported?[PositionKeys.sheetIndex], 1);
    sheet.search('alice');
    expect(sheet.matches.map((m) => (m.row, m.column)), [(2, 1)]);
  });

  test('zoom stays within 75%-200%', () {
    final sheet = SpreadsheetController();
    for (var i = 0; i < 10; i++) {
      sheet.zoomIn();
    }
    expect(sheet.zoom, SpreadsheetController.maxZoom);
    for (var i = 0; i < 10; i++) {
      sheet.zoomOut();
    }
    expect(sheet.zoom, SpreadsheetController.minZoom);
  });
}
