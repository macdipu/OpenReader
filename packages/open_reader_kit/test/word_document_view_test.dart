import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_reader_kit/docx.dart';
import 'package:open_reader_kit/open_reader_kit.dart';
import 'package:open_reader_kit/testing.dart';

void main() {
  Future<WordDocumentController> load(WidgetTester tester, Uint8List bytes) async {
    final controller = WordDocumentController();
    await tester.runAsync(() => controller.load(bytes));
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pumpView(WidgetTester tester, WordDocumentController controller) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WordDocumentView(controller: controller))));
    await tester.pump();
  }

  bool shows(String text) => find.textContaining(text, findRichText: true).evaluate().isNotEmpty;

  testWidgets('renders the python-docx fixture: text, lists, table, image', (tester) async {
    final controller = await load(tester, File('test/fixtures/word/features.docx').readAsBytesSync());
    expect(controller.error, isNull);
    await pumpView(tester, controller);
    expect(shows('Report header'), isTrue);
    expect(shows('Quarterly Report'), isTrue);
    expect(shows('Visit our site'), isTrue);
    expect(find.text('•'), findsWidgets);
    expect(find.text('2.'), findsOneWidget);
    expect(shows('wide'), isTrue);
    expect(shows('tall'), isTrue);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('search highlights matches and jumps to them', (tester) async {
    final controller = await load(
      tester,
      buildDocx([for (var i = 0; i < 300; i++) '<w:p><w:r><w:t>Line $i${i == 250 ? ' needle' : ''}</w:t></w:r></w:p>'].join()),
    );
    await pumpView(tester, controller);
    expect(shows('Line 250'), isFalse, reason: 'not built yet: the list is lazy');
    controller.search('NEEDLE');
    expect(controller.searchController.matchCount, 1);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(shows('Line 250 needle'), isTrue);
    expect(tester.getTopLeft(find.textContaining('Line 250', findRichText: true)).dy, lessThan(600));
  });

  testWidgets('a note mark opens the note', (tester) async {
    final controller = await load(
      tester,
      buildDocx(
        '<w:p><w:r><w:t>Claim</w:t></w:r><w:r><w:footnoteReference w:id="1"/></w:r></w:p>',
        footnotes: '<w:footnote w:id="1"><w:p><w:r><w:footnoteRef/></w:r>'
            '<w:r><w:t xml:space="preserve"> The source.</w:t></w:r></w:p></w:footnote>',
      ),
    );
    await pumpView(tester, controller);
    expect(find.text('Notes'), findsOneWidget);
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.textContaining('The source.', findRichText: true)),
        findsOneWidget);
  });

  testWidgets('a damaged file is a typed error', (tester) async {
    final controller = await load(tester, Uint8List.fromList([1, 2, 3]));
    expect(controller.error, DocumentLoadError.corrupted);
  });
}
