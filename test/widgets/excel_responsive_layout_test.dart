import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/features/excel_reader/presentation/excel_reader_controller.dart';
import 'package:universal_document_viewer/spreadsheet.dart' show GridSelection, SpreadsheetView;
import 'package:universal_document_viewer/testing.dart';

import '../helpers/excel_reader_harness.dart';
import '../helpers/temp_dir.dart';

/// CR-EXCEL-READER-AUDIT S5: the name/formula bar, the read-only mark and
/// the phone, tablet and desktop layouts of the Excel reader.
void main() {
  late Directory root;

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-excel-layout-');
  });

  tearDown(() async {
    Get.reset();
    await deleteTempDir(root);
  });

  final longText = List.filled(20, 'a long note').join(' ');

  Future<ExcelReaderController> open(WidgetTester tester) async => (await tester.runAsync(
        () => openExcelReader(
          root,
          'budget.xlsx',
          buildXlsx([
            XlsxTestSheet('Summary', {
              'A1': 'Item',
              'B1': 'Cost',
              'A2': 'Rent',
              'B2': 1200,
              'A3': 'Total',
              'B3': const XlsxTestFormula('SUM(B2:B2)', cached: 1200),
              'C2': longText,
            }),
            const XlsxTestSheet('Notes', {'A1': 'n'}),
          ]),
        ),
      ))!;

  Finder nameBox() => find.byKey(const Key('formula-bar-name'));
  String value(WidgetTester tester) {
    final widget = tester.widget(find.byKey(const Key('formula-bar-value')));
    return widget is Text ? widget.data! : (widget as SelectableText).data!;
  }

  const phone = Size(390, 844);
  const phoneLandscape = Size(844, 390);
  const tabletPortrait = Size(820, 1180);
  const tabletLandscape = Size(1180, 820);
  const desktop = Size(1440, 900);

  for (final (name, size) in [
    ('phone', phone),
    ('phone landscape', phoneLandscape),
    ('tablet portrait', tabletPortrait),
    ('tablet landscape', tabletLandscape),
    ('desktop', desktop),
  ]) {
    testWidgets('$name: lays out without overflow, with the grid, tabs and toolbar', (tester) async {
      final controller = await open(tester);
      await showExcelReader(tester, controller, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.byTooltip('All sheets'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Read-only: this reader never changes the file'), findsOneWidget);
      // Tapping a cell shows its name bar and the grid's own status bar.
      await tester.tap(find.text('Rent'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: nameBox(), matching: find.text('A2')), findsOneWidget);
    });
  }

  testWidgets('phone: the name bar appears only with a selection; Favorite is in More', (tester) async {
    final controller = await open(tester);
    await showExcelReader(tester, controller, size: phone);
    expect(nameBox(), findsNothing);
    expect(find.text('Read-only'), findsNothing, reason: 'just the lock on a phone');
    expect(find.byTooltip('Add to favorites'), findsNothing);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Add to favorites'), findsOneWidget);
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    expect(nameBox(), findsOneWidget);
    expect(value(tester), 'Rent');

    controller.sheet.clearSelection();
    await tester.pumpAndSettle();
    expect(nameBox(), findsNothing);
  });

  testWidgets('phone on its side: the name bar waits for a selection, leaving the grid room', (tester) async {
    final controller = await open(tester);
    await showExcelReader(tester, controller, size: phoneLandscape);
    expect(nameBox(), findsNothing);
    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    expect(nameBox(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet and desktop: the name bar is always there; "Read-only" is spelled out', (tester) async {
    final controller = await open(tester);
    await showExcelReader(tester, controller, size: desktop);
    expect(nameBox(), findsOneWidget);
    expect(value(tester), '');
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.byTooltip('Add to favorites'), findsOneWidget);
  });

  testWidgets('a formula cell shows fx and its formula; a number shows its value', (tester) async {
    final controller = await open(tester);
    await showExcelReader(tester, controller, size: desktop);
    controller.sheet.select(const GridSelection.cell(2, 1));
    await tester.pumpAndSettle();
    expect(find.descendant(of: nameBox(), matching: find.text('B3')), findsOneWidget);
    expect(value(tester), '=SUM(B2:B2)');

    controller.sheet.select(const GridSelection.cell(1, 1));
    await tester.pumpAndSettle();
    expect(value(tester), '1200');
  });

  testWidgets('tapping the name box goes to a cell', (tester) async {
    final controller = await open(tester);
    await showExcelReader(tester, controller, size: desktop);
    controller.sheet.select(const GridSelection.cell(0, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('formula-bar-goto')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'the Go to cell dialog');
    await tester.enterText(find.byType(TextField).last, 'B3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.sheet.goToTarget?.row, 2);
    expect(controller.sheet.goToTarget?.column, 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the selection uses the Excel accent, and the grid has its own scrollbars', (tester) async {
    final controller = await open(tester);
    await showExcelReader(tester, controller, size: phone);
    final accent = DocumentCategory.excel.accentColor(tester.element(find.byType(Scaffold).first));
    controller.sheet.select(const GridSelection.cell(1, 0));
    await tester.pump();
    // (The name bar also shows "Rent" once it is selected: look inside the grid.)
    final rent = find.descendant(of: find.byType(SpreadsheetView), matching: find.text('Rent'));
    final cell = tester.widget<Container>(find.ancestor(of: rent, matching: find.byType(Container)).first);
    final border = (cell.foregroundDecoration! as BoxDecoration).border! as Border;
    expect(border.top.color, accent);
    // One pair, the grid's: the app no longer wraps a second set around it.
    expect(find.byType(Scrollbar), findsNWidgets(2));
  });

  testWidgets('a long value is one line until expanded', (tester) async {
    final controller = await open(tester);
    await showExcelReader(tester, controller, size: tabletPortrait);
    controller.sheet.select(const GridSelection.cell(1, 2));
    await tester.pumpAndSettle();
    expect(tester.widget(find.byKey(const Key('formula-bar-value'))), isA<Text>());
    final collapsed = tester.getSize(find.byKey(const Key('formula-bar-value')));

    await tester.tap(find.byTooltip('Show all'));
    await tester.pumpAndSettle();
    expect(tester.widget(find.byKey(const Key('formula-bar-value'))), isA<SelectableText>());
    expect(value(tester), longText);
    expect(tester.getSize(find.byKey(const Key('formula-bar-value'))).height, greaterThan(collapsed.height));

    await tester.tap(find.byTooltip('Collapse'));
    await tester.pumpAndSettle();
    expect(tester.widget(find.byKey(const Key('formula-bar-value'))), isA<Text>());
  });
}
