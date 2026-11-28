import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/presentation/widgets/reader/reader_outline.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';

void main() {
  Future<OutlineEntry?> open(WidgetTester tester, List<OutlineEntry> entries, {OutlineEntry? tap}) async {
    OutlineEntry? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderOutlineButton(load: () async => entries, onSelected: (e) => chosen = e),
      ),
    ));
    await tester.tap(find.byTooltip('Contents'));
    await tester.pumpAndSettle();
    if (tap != null) {
      await tester.tap(find.text(tap.title));
      await tester.pumpAndSettle();
    }
    return chosen;
  }

  testWidgets('lists the entries and goes to the one chosen', (tester) async {
    const intro = OutlineEntry(title: 'Introduction', level: 0, target: 1);
    const detail = OutlineEntry(title: 'Details', level: 1, target: 4);
    final chosen = await open(tester, [intro, detail], tap: detail);
    expect(chosen, detail);
    expect(find.text('Introduction'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('a heading that leads nowhere cannot be chosen', (tester) async {
    const group = OutlineEntry(title: 'Part one', level: 0);
    final chosen = await open(tester, [group], tap: group);
    expect(chosen, isNull);
    expect(find.text('Part one'), findsOneWidget, reason: 'the sheet stays open');
  });

  testWidgets('a document with no outline says so', (tester) async {
    await open(tester, const []);
    expect(find.text('This document has no contents list.'), findsOneWidget);
  });
}
