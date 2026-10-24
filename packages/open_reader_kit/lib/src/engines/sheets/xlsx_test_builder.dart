import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A sheet for [buildXlsx]: cells by address (`'B3'`), and whether the
/// author hid it (`'hidden'` / `'veryHidden'`).
class XlsxTestSheet {
  const XlsxTestSheet(this.name, this.cells, {this.state, this.frozenRows = 0, this.frozenColumns = 0});

  final String name;

  /// `String` (a shared string), `num`, `bool`, [XlsxTestFormula] or
  /// [XlsxTestCell] (a value with formatting).
  final Map<String, Object> cells;
  final String? state;
  final int frozenRows;
  final int frozenColumns;
}

/// A formula and the result saved with it (none when [cached] is null).
class XlsxTestFormula {
  const XlsxTestFormula(this.formula, {this.cached});
  final String formula;
  final Object? cached;
}

/// A value with formatting: bold, a solid fill (`'FFC000'`), a number
/// format code.
class XlsxTestCell {
  const XlsxTestCell(this.value, {this.bold = false, this.fill, this.numberFormat});
  final Object value;
  final bool bold;
  final String? fill;
  final String? numberFormat;
}

/// Builds a minimal `.xlsx` for tests: workbook + rels, shared strings,
/// styles and the sheets - just the parts `XlsxReader` reads.
Uint8List buildXlsx(List<XlsxTestSheet> sheets) {
  const main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const pkg = 'http://schemas.openxmlformats.org/package/2006/relationships';
  String esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

  final strings = <String>[];
  int sharedIndex(String s) {
    final i = strings.indexOf(s);
    if (i != -1) return i;
    strings.add(s);
    return strings.length - 1;
  }

  // Styles: xf 0 is plain; each distinct (bold, fill, format) adds one.
  final styleKeys = <String>[''];
  final customFormats = <String>[];
  final fills = <String>[];
  int styleFor(XlsxTestCell cell) {
    final key = '${cell.bold}|${cell.fill}|${cell.numberFormat}';
    final i = styleKeys.indexOf(key);
    if (i != -1) return i;
    styleKeys.add(key);
    if (cell.fill case final fill? when !fills.contains(fill)) fills.add(fill);
    if (cell.numberFormat case final code? when !customFormats.contains(code)) customFormats.add(code);
    return styleKeys.length - 1;
  }

  String cellXml(String ref, Object raw) {
    var value = raw;
    var style = 0;
    if (value is XlsxTestCell) {
      style = styleFor(value);
      value = value.value;
    }
    final s = style == 0 ? '' : ' s="$style"';
    return switch (value) {
      final String text => '<c r="$ref" t="s"$s><v>${sharedIndex(text)}</v></c>',
      final bool flag => '<c r="$ref" t="b"$s><v>${flag ? 1 : 0}</v></c>',
      final num number => '<c r="$ref"$s><v>$number</v></c>',
      XlsxTestFormula(:final formula, :final cached) => switch (cached) {
          null => '<c r="$ref"$s><f>${esc(formula)}</f></c>',
          final String text => '<c r="$ref" t="str"$s><f>${esc(formula)}</f><v>${esc(text)}</v></c>',
          final Object other => '<c r="$ref"$s><f>${esc(formula)}</f><v>$other</v></c>',
        },
      _ => throw ArgumentError('Unsupported cell value: $value'),
    };
  }

  int rowOf(String ref) => int.parse(ref.replaceAll(RegExp('[A-Z]'), ''));

  final archive = Archive();
  void add(String name, String text) => archive.addFile(ArchiveFile.bytes(name, utf8.encode(text)));

  add('_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="$pkg"><Relationship Id="rId1" Type="$rel/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  add('xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="$main" xmlns:r="$rel"><sheets>'
      '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${esc(sheets[i].name)}" sheetId="${i + 1}"${sheets[i].state == null ? '' : ' state="${sheets[i].state}"'} r:id="rId${i + 1}"/>'].join()}'
      '</sheets></workbook>');

  for (var i = 0; i < sheets.length; i++) {
    final sheet = sheets[i];
    final byRow = <int, List<MapEntry<String, Object>>>{};
    for (final entry in sheet.cells.entries) {
      byRow.putIfAbsent(rowOf(entry.key), () => []).add(entry);
    }
    final rowNumbers = byRow.keys.toList()..sort();
    final pane = sheet.frozenRows == 0 && sheet.frozenColumns == 0
        ? ''
        : '<sheetViews><sheetView workbookViewId="0"><pane xSplit="${sheet.frozenColumns}" ySplit="${sheet.frozenRows}" state="frozen"/></sheetView></sheetViews>';
    add('xl/worksheets/sheet${i + 1}.xml',
        '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="$main">$pane<sheetData>'
        '${[for (final r in rowNumbers) '<row r="$r">${[for (final e in byRow[r]!) cellXml(e.key, e.value)].join()}</row>'].join()}'
        '</sheetData></worksheet>');
  }

  add('xl/sharedStrings.xml',
      '<?xml version="1.0" encoding="UTF-8"?><sst xmlns="$main">${[for (final s in strings) '<si><t xml:space="preserve">${esc(s)}</t></si>'].join()}</sst>');

  final xfs = [
    for (final key in styleKeys)
      if (key.isEmpty)
        '<xf numFmtId="0" fontId="0" fillId="0"/>'
      else
        () {
          final [bold, fill, format] = key.split('|');
          final fontId = bold == 'true' ? 1 : 0;
          final fillId = fill == 'null' ? 0 : 2 + fills.indexOf(fill);
          final numFmtId = format == 'null' ? 0 : 164 + customFormats.indexOf(format);
          return '<xf numFmtId="$numFmtId" fontId="$fontId" fillId="$fillId"/>';
        }(),
  ];
  add('xl/styles.xml',
      '<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="$main">'
      '<numFmts>${[for (var i = 0; i < customFormats.length; i++) '<numFmt numFmtId="${164 + i}" formatCode="${esc(customFormats[i]).replaceAll('"', '&quot;')}"/>'].join()}</numFmts>'
      '<fonts><font/><font><b/></font></fonts>'
      '<fills><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '${[for (final f in fills) '<fill><patternFill patternType="solid"><fgColor rgb="FF$f"/></patternFill></fill>'].join()}</fills>'
      '<cellXfs>${xfs.join()}</cellXfs></styleSheet>');

  final workbookRels = [
    for (var i = 0; i < sheets.length; i++)
      '<Relationship Id="rId${i + 1}" Type="$rel/worksheet" Target="worksheets/sheet${i + 1}.xml"/>',
    '<Relationship Id="rId${sheets.length + 1}" Type="$rel/sharedStrings" Target="sharedStrings.xml"/>',
    '<Relationship Id="rId${sheets.length + 2}" Type="$rel/styles" Target="styles.xml"/>',
  ];
  add('xl/_rels/workbook.xml.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="$pkg">${workbookRels.join()}</Relationships>');
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
