import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/features/excel_reader/presentation/excel_reader_controller.dart';
import 'package:universal_document_viewer/testing.dart';

import '../helpers/excel_reader_harness.dart';
import '../helpers/temp_dir.dart';

/// CR-EXCEL-READER-AUDIT S4 in the app: the password message, hidden-sheet
/// indicator, sheet picker and "not shown" notice.
void main() {
  late Directory root;

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-excel-gaps-');
  });

  tearDown(() async {
    Get.reset();
    await deleteTempDir(root);
  });

  Future<ExcelReaderController> open(String name, Uint8List bytes) => openExcelReader(root, name, bytes);

  Future<void> show(WidgetTester tester, ExcelReaderController controller, {Size size = const Size(390, 844)}) =>
      showExcelReader(tester, controller, size: size);

  Uint8List encrypted() {
    final bytes = BytesBuilder()
      ..add([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
      ..add(List.filled(1024, 0))
      ..add([for (final unit in 'EncryptedPackage'.codeUnits) ...[unit, 0]])
      ..add(List.filled(512, 0));
    return bytes.toBytes();
  }

  test('a password-protected workbook says so instead of "damaged"', () async {
    final controller = await open('locked.xlsx', encrypted());
    expect(controller.status.value, StateStatus.error);
    expect(controller.errorMessage.value, contains('password protected'));
  });

  test('an .xlsm workbook opens', () async {
    final controller = await open('macros.xlsm', buildXlsx(const [XlsxTestSheet('M', {'A1': 'ok'})]));
    expect(controller.status.value, StateStatus.success);
    expect(controller.currentRows[0][0]?.text, 'ok');
  });

  testWidgets('hidden sheets get a chip; the picker lists every sheet and names the hidden ones', (tester) async {
    final controller = (await tester.runAsync(() => open(
          'hidden.xlsx',
          buildXlsx(const [
            XlsxTestSheet('Summary', {'A1': 1}),
            XlsxTestSheet('Rates', {'A1': 2}, state: 'hidden'),
            XlsxTestSheet('April', {'A1': 3}),
          ]),
        )))!;
    expect(controller.hiddenSheetNames, ['Rates']);
    await show(tester, controller);

    expect(find.text('1 hidden'), findsOneWidget);
    await tester.tap(find.byTooltip('All sheets'));
    await tester.pumpAndSettle();
    expect(find.text('Sheets (2)'), findsOneWidget);
    expect(find.text('Hidden by the author (1)'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Rates'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'April'));
    await tester.pumpAndSettle();
    expect(controller.activeSheetIndex.value, 1);
    expect(find.text('Sheets (2)'), findsNothing);
    // Lets the reader's 2 s position save run.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('one visible sheet plus a hidden one still shows the bar', (tester) async {
    final controller = (await tester.runAsync(() => open(
          'one.xlsx',
          buildXlsx(const [
            XlsxTestSheet('Only', {'A1': 1}),
            XlsxTestSheet('Secret', {'A1': 2}, state: 'hidden'),
          ]),
        )))!;
    await show(tester, controller);
    expect(find.text('1 hidden'), findsOneWidget);
  });

  testWidgets('a sheet with a picture and validation names them; Dismiss hides it for that sheet', (tester) async {
    final controller = (await tester.runAsync(() => open(
          'pictures.xlsx',
          buildXlsx(const [
            XlsxTestSheet(
              'Chart',
              {'A1': 1},
              afterSheetData: '<dataValidations count="1"><dataValidation type="list" sqref="A1"/></dataValidations>'
                  '<drawing r:id="rId5" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>',
            ),
            XlsxTestSheet('Plain', {'A1': 2}),
          ]),
        )))!;
    await show(tester, controller, size: const Size(1440, 900));

    expect(find.textContaining('Not shown: pictures, charts and shapes, drop-down lists'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not shown:'), findsNothing);

    controller.switchSheet(1);
    await tester.pumpAndSettle();
    expect(find.textContaining('Not shown:'), findsNothing, reason: 'the plain sheet has nothing missing');
    controller.switchSheet(0);
    await tester.pumpAndSettle();
    expect(find.textContaining('Not shown:'), findsNothing, reason: 'stays dismissed for that sheet');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('search covers every sheet by default; the label names the match\'s sheet; options apply', (tester) async {
    final controller = (await tester.runAsync(() => open(
          'search.xlsx',
          buildXlsx(const [
            XlsxTestSheet('North', {'A1': 'Total', 'A2': XlsxTestFormula('SUM(B1:B2)', cached: 5)}),
            XlsxTestSheet('South', {'B3': 'total due'}),
          ]),
        )))!;
    await show(tester, controller, size: const Size(1440, 900));
    expect(find.byTooltip('Search in workbook'), findsOneWidget);
    await tester.tap(find.byTooltip('Search in workbook'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'total');
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 · North'), findsOneWidget);
    await tester.tap(find.byTooltip('Next match'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 · South'), findsOneWidget);
    expect(controller.activeSheetIndex.value, 1);

    // Match case: lower-case "total" leaves only South's "total due".
    await tester.tap(find.byTooltip('Search options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match case'));
    await tester.pumpAndSettle();
    expect(controller.searchOptions.value.matchCase, isTrue);
    expect(find.text('1 of 1 · South'), findsOneWidget);

    // Formulas, any case.
    await tester.tap(find.byTooltip('Search options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match case'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search formulas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sum(');
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 · North'), findsOneWidget);

    // This sheet only.
    await tester.tap(find.byTooltip('Search options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All sheets'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1'), findsOneWidget, reason: 'no sheet name once the search is of one sheet');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a single-sheet workbook with nothing hidden has no tab bar', (tester) async {
    final controller =
        (await tester.runAsync(() => open('plain.xlsx', buildXlsx(const [XlsxTestSheet('S', {'A1': 1})]))))!;
    await show(tester, controller);
    expect(find.byTooltip('All sheets'), findsNothing);
    expect(find.textContaining('Not shown:'), findsNothing);
  });
}
