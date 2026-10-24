import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_reader_kit/sheets.dart';

void main() {
  Future<SpreadsheetController> load(WidgetTester tester) async {
    final controller = SpreadsheetController();
    await tester.runAsync(() => controller.loadXlsx(File('test/fixtures/sheets/features.xlsx').readAsBytesSync()));
    return controller;
  }

  Future<void> pumpGrid(WidgetTester tester, SpreadsheetController controller) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SheetGrid(controller: controller))));
    await tester.pump();
  }

  testWidgets('hidden rows and columns are left out; widths come from the file', (tester) async {
    final controller = await load(tester);
    await pumpGrid(tester, controller);
    // Row 9 and column G are hidden.
    expect(find.bySemanticsLabel('Row 8'), findsOneWidget);
    expect(find.bySemanticsLabel('Row 9'), findsNothing);
    expect(find.bySemanticsLabel('Column F'), findsOneWidget);
    expect(find.bySemanticsLabel('Column G'), findsNothing);
    // Column A is 20 characters wide, B the default.
    final a = tester.getSize(find.bySemanticsLabel('Column A')).width;
    final b = tester.getSize(find.bySemanticsLabel('Column B')).width;
    expect(b, SpreadsheetController.cellWidth);
    expect(a, closeTo(SheetGeometry.columnWidthOf(20), 0.5));
  });

  testWidgets('a merged area shows its value once, across its columns', (tester) async {
    final controller = await load(tester);
    await pumpGrid(tester, controller);
    final wide = find.text('wide');
    expect(wide, findsOneWidget);
    final cell = find.ancestor(of: wide, matching: find.byType(InkWell)).first;
    expect(tester.getSize(cell).width, closeTo(3 * SpreadsheetController.cellWidth, 0.5));
    // A1:C10's merge would cross the frozen column, so it stays one cell.
    final merged = find.ancestor(of: find.text('merged'), matching: find.byType(InkWell)).first;
    expect(tester.getSize(merged).width, closeTo(SheetGeometry.columnWidthOf(20), 0.5));
  });

  testWidgets('a link to another sheet switches to it', (tester) async {
    final controller = await load(tester);
    expect(controller.sheetNames, ['Summary', 'Later']);
    expect(controller.openInternalLink('Later!B3'), isTrue);
    expect(controller.activeSheetIndex, 1);
    expect(controller.openInternalLink("'No such sheet'!A1"), isFalse);
    expect(controller.openInternalLink('B3'), isTrue);
  });
}
