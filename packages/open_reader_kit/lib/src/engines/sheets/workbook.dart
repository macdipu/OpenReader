import 'number_format.dart';

/// A spreadsheet as read from an `.xlsx` or CSV file: its sheets in
/// workbook order, hidden ones included (a reader decides whether to show
/// them).
///
/// Plain data all the way down, so a workbook parsed in a background
/// isolate can be sent back to the UI isolate.
class Workbook {
  const Workbook(this.sheets, {this.date1904 = false});

  final List<Worksheet> sheets;

  /// Whether date serials count from 1904-01-01 (old Mac Excel files)
  /// rather than 1900-01-00. Cell text already accounts for it.
  final bool date1904;

  List<String> get sheetNames => [for (final sheet in sheets) sheet.name];

  Worksheet? operator [](String name) {
    for (final sheet in sheets) {
      if (sheet.name == name) return sheet;
    }
    return null;
  }
}

enum SheetVisibility {
  visible,

  /// Hidden by the author; Excel's "Unhide" lists it.
  hidden,

  /// Hidden so that Excel's "Unhide" doesn't list it.
  veryHidden,
}

class Worksheet {
  const Worksheet({
    required this.name,
    required this.rows,
    this.visibility = SheetVisibility.visible,
    this.frozenRows = 0,
    this.frozenColumns = 0,
    this.layout = SheetLayout.standard,
    this.merges = const [],
    this.hyperlinks = const {},
  });

  final String name;
  final SheetVisibility visibility;

  /// Column widths, row heights and what the author hid.
  final SheetLayout layout;

  /// Merged areas: each shows its top-left cell across the whole range.
  final List<CellRange> merges;

  /// Link targets by cell: a URL, or a place in the workbook (`Sheet2!A1`).
  final Map<CellAddress, String> hyperlinks;

  /// Rows from the first (index 0 = row 1) to the last one holding a cell.
  /// Rows have different lengths: each stops at its own last cell, and a
  /// missing cell is null.
  final List<List<SheetCell?>> rows;

  /// Rows/columns frozen at the top/left by the author.
  final int frozenRows;
  final int frozenColumns;

  /// Width of the widest row.
  int get columnCount {
    var widest = 0;
    for (final row in rows) {
      if (row.length > widest) widest = row.length;
    }
    return widest;
  }
}

/// A zero-based cell position.
typedef CellAddress = ({int row, int column});

/// A rectangle of cells, zero-based and inclusive (`A1:B2` is rows 0-1,
/// columns 0-1).
class CellRange {
  const CellRange({required this.firstRow, required this.firstColumn, required this.lastRow, required this.lastColumn});

  final int firstRow;
  final int firstColumn;
  final int lastRow;
  final int lastColumn;

  bool contains(int row, int column) =>
      row >= firstRow && row <= lastRow && column >= firstColumn && column <= lastColumn;

  @override
  bool operator ==(Object other) =>
      other is CellRange &&
      other.firstRow == firstRow &&
      other.firstColumn == firstColumn &&
      other.lastRow == lastRow &&
      other.lastColumn == lastColumn;

  @override
  int get hashCode => Object.hash(firstRow, firstColumn, lastRow, lastColumn);

  @override
  String toString() => 'CellRange($firstRow,$firstColumn..$lastRow,$lastColumn)';
}

/// How a sheet's rows and columns are sized, in the file's own units:
/// column widths in characters of the default font's digit width (Excel's
/// "8.43"), row heights in points.
class SheetLayout {
  const SheetLayout({
    this.defaultColumnWidth = 8.43,
    this.defaultRowHeight = 15,
    this.columnWidths = const {},
    this.rowHeights = const {},
    this.hiddenColumns = const {},
    this.hiddenRows = const {},
  });

  static const standard = SheetLayout();

  final double defaultColumnWidth;
  final double defaultRowHeight;
  final Map<int, double> columnWidths;
  final Map<int, double> rowHeights;
  final Set<int> hiddenColumns;
  final Set<int> hiddenRows;

  double columnWidth(int column) => columnWidths[column] ?? defaultColumnWidth;
  double rowHeight(int row) => rowHeights[row] ?? defaultRowHeight;
}

class SheetCell {
  const SheetCell(this.value, {this.style = CellStyle.plain, this.date1904 = false});

  /// Null for a cell that only carries formatting (e.g. a fill colour).
  final CellValue? value;
  final CellStyle style;

  /// Copied from the [Workbook], so [text] can place date serials.
  final bool date1904;

  /// What a reader shows: numbers and dates formatted with the cell's
  /// number format, and for a formula its saved result. A formula saved
  /// without a result (some generators skip it) shows the formula, marked
  /// with `=`.
  String get text => switch (value) {
        null => '',
        TextValue(:final text) => text,
        final NumberValue number => _formatNumber(number),
        BoolValue(:final value) => value ? 'TRUE' : 'FALSE',
        ErrorValue(:final code) => code,
        FormulaValue(:final formula, :final cached) => switch (cached) {
            null || TextValue(text: '') => '=$formula',
            final cached => SheetCell(cached, style: style, date1904: date1904).text,
          },
      };

  /// The cell's number, for a selection's Sum/Average: a number cell, or a
  /// formula whose saved result is one. Text that looks numeric isn't
  /// counted, as in Excel's status bar.
  num? get number => switch (value) {
        NumberValue(:final value) => value,
        FormulaValue(cached: NumberValue(:final value)) => value,
        _ => null,
      };

  String _formatNumber(NumberValue number) {
    if (number.text case final text? when style.numberFormat.isGeneral) return text;
    return style.numberFormat.format(number.value, date1904: date1904);
  }
}

/// A cell's content.
sealed class CellValue {
  const CellValue();
}

class TextValue extends CellValue {
  const TextValue(this.text);
  final String text;
}

/// A number. Dates and times are numbers too (days since the workbook's
/// epoch, as Excel stores them); the cell's number format shows them as
/// dates.
class NumberValue extends CellValue {
  const NumberValue(this.value, {this.text});
  final num value;

  /// The number as written in the file, for CSV: shown as-is under the
  /// General format so `007` or `1.50` keep their look.
  final String? text;
}

class BoolValue extends CellValue {
  const BoolValue(this.value);
  final bool value;
}

/// An error result such as `#DIV/0!` or `#N/A`.
class ErrorValue extends CellValue {
  const ErrorValue(this.code);
  final String code;
}

/// A formula and the result Excel saved with it ([cached]; null when the
/// file has none).
class FormulaValue extends CellValue {
  const FormulaValue(this.formula, {this.cached});
  final String formula;
  final CellValue? cached;
}

enum HorizontalAlignment {
  /// Excel's default: text left, numbers and dates right, booleans and
  /// errors centred.
  general,
  left,
  center,
  right,
  fill,
  justify,
  centerContinuous,
  distributed,
}

enum VerticalAlignment { top, center, bottom, justify, distributed }

/// The parts of a cell's formatting a reader shows.
class CellStyle {
  const CellStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.fontSize,
    this.textColor,
    this.fillColor,
    this.horizontalAlignment = HorizontalAlignment.general,
    this.verticalAlignment = VerticalAlignment.bottom,
    this.wrapText = false,
    this.numberFormat = NumberFormat.general,
  });

  static const plain = CellStyle();

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  /// In points; null for the workbook's default (11 pt in Office).
  final double? fontSize;

  /// Text colour as 0xAARRGGBB; null for automatic (black on white).
  final int? textColor;

  /// Solid background as 0xAARRGGBB, or null for none.
  final int? fillColor;

  final HorizontalAlignment horizontalAlignment;
  final VerticalAlignment verticalAlignment;
  final bool wrapText;

  final NumberFormat numberFormat;
}
