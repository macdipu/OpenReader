import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_reader_kit/open_reader_kit.dart';
import 'package:open_reader_kit/testing.dart';

/// Lets the file read and parse finish in real time, then builds.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('kit-viewer-'));
  tearDown(() async => dir.delete(recursive: true));

  Future<void> pumpViewer(WidgetTester tester, String name, List<int> bytes) async {
    final path = '${dir.path}/$name';
    await tester.runAsync(() => File(path).writeAsBytes(bytes));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DocumentViewer.file(path))));
    await settle(tester);
  }

  testWidgets('opens text', (tester) async {
    await pumpViewer(tester, 'notes.txt', 'first line\nsecond line'.codeUnits);
    expect(find.text('second line'), findsOneWidget);
  });

  testWidgets('opens CSV in the sheet grid', (tester) async {
    await pumpViewer(tester, 'data.csv', 'Name,Score\nAlice,97\n'.codeUnits);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
  });

  testWidgets('opens PowerPoint with slide navigation', (tester) async {
    await pumpViewer(tester, 'deck.pptx', buildPptx([titleShape('Hello'), titleShape('Bye')]));
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('says when a type is not supported', (tester) async {
    await pumpViewer(tester, 'old.ppt', [1, 2, 3]);
    expect(find.text('This file type is not supported.'), findsOneWidget);
  });

  testWidgets('says when a file is damaged', (tester) async {
    await pumpViewer(tester, 'broken.xlsx', [1, 2, 3]);
    expect(find.text('This document may be damaged or incomplete.'), findsOneWidget);
  });

  testWidgets('reopens when the path changes', (tester) async {
    await pumpViewer(tester, 'a.txt', 'from a'.codeUnits);
    final second = '${dir.path}/b.txt';
    await tester.runAsync(() => File(second).writeAsBytes('from b'.codeUnits));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DocumentViewer.file(second))));
    await settle(tester);
    expect(find.text('from b'), findsOneWidget);
    expect(find.text('from a'), findsNothing);
  });

  testWidgets('a load that outlives the viewer is dropped', (tester) async {
    final path = '${dir.path}/late.txt';
    await tester.runAsync(() => File(path).writeAsBytes('late'.codeUnits));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DocumentViewer.file(path))));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
