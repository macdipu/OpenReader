import 'package:open_reader_kit/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Round-trips through encode/decode, so cells are read the way a real file is.
  xls.Sheet reread(void Function(xls.Sheet sheet) fill) {
    final workbook = xls.Excel.createExcel();
    fill(workbook['Sheet1']);
    return xls.Excel.decodeBytes(workbook.encode()!)['Sheet1'];
  }

  xls.Data cell(xls.Sheet sheet, String address) => sheet.cell(xls.CellIndex.indexByString(address));

  test('a formula shows the result saved in the file, not the formula', () {
    final sheet = reread((s) {
      s.cell(xls.CellIndex.indexByString('A1')).value = const xls.FormulaCellValue('SUM(B1:B2)', cachedValue: '2200');
      s.cell(xls.CellIndex.indexByString('A2')).value = const xls.FormulaCellValue('B3&"!"', cachedValue: 'Done!');
    });
    expect(cell(sheet, 'A1').readerText, '2200');
    expect(cell(sheet, 'A2').readerText, 'Done!');
  });

  test('a formula saved without a result shows the formula, marked with =', () {
    final sheet = reread((s) => s.cell(xls.CellIndex.indexByString('A1')).value = const xls.FormulaCellValue('SUM(B1:B2)'));
    expect(cell(sheet, 'A1').readerText, '=SUM(B1:B2)');
  });

  test('other cells read as before', () {
    final sheet = reread((s) {
      s.cell(xls.CellIndex.indexByString('A1')).value = xls.TextCellValue('Name');
      s.cell(xls.CellIndex.indexByString('A2')).value = xls.IntCellValue(42);
    });
    expect(cell(sheet, 'A1').readerText, 'Name');
    expect(cell(sheet, 'A2').readerText, '42');
  });
}
