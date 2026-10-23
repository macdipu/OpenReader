import 'package:excel_plus/excel_plus.dart' as xls;

extension CellText on xls.Data {
  /// What a reader shows for this cell. Same as `excel_plus`'s `displayText`,
  /// except for formulas: that returns the formula itself, so a workbook's
  /// totals read `SUM(B2:B5)`. Excel saves each formula's last result in the
  /// file, so show that (number-formatted); a file saved without one (some
  /// generators skip it) shows the formula, marked with `=`.
  String get readerText {
    final v = value;
    if (v is! xls.FormulaCellValue) return displayText;
    final cached = v.cachedValue;
    if (cached == null || cached.isEmpty) return '=${v.formula}';
    final number = num.tryParse(cached);
    if (number == null) return cached;
    return (cellStyle?.numberFormat ?? xls.NumFormat.standard_0).format(number);
  }
}

extension CellNumber on xls.Data {
  /// The cell's number, for a selection's Sum/Average: a number cell, or a
  /// formula whose saved result is one. Text that looks numeric isn't
  /// counted, as in Excel's status bar.
  num? get numericValue => switch (value) {
        xls.IntCellValue(:final value) => value,
        xls.DoubleCellValue(:final value) => value,
        xls.FormulaCellValue(:final cachedValue?) => num.tryParse(cachedValue),
        _ => null,
      };
}
