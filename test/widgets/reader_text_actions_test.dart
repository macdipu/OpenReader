import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/presentation/widgets/reader/reader_text_actions.dart';
import 'package:universal_document_viewer/plain_text.dart';

/// CR-READER-SELECT-OCR SO-06: the readers' "Copy all text" entry. Copying a
/// selection and Select all are the system's (toolbar, right click, keys).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;

  setUp(() {
    Get.testMode = true;
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<PlainTextController> pumpReader(WidgetTester tester, {String text = 'alpha beta\ngamma delta'}) async {
    final controller = PlainTextController();
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.loadBytes(Uint8List.fromList(utf8.encode(text))));
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<int>(
                onSelected: (_) => runReaderCopyAll(controller),
                itemBuilder: (context) => readerCopyAllMenuItems(1),
              ),
            ],
          ),
          body: PlainTextView(controller: controller),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('the menu offers only Copy all text; Copy and Select all are left to the system', (tester) async {
    await pumpReader(tester);
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('Copy all text'), findsOneWidget);
    expect(find.text('Copy selected text'), findsNothing);
    expect(find.text('Select all'), findsNothing);
  });

  testWidgets('Copy all text copies the document without a selection', (tester) async {
    await pumpReader(tester);
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy all text'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(clipboard, 'alpha beta\ngamma delta');
    expect(find.text('All text copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a document with no text says so and copies nothing', (tester) async {
    final controller = PlainTextController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
    await runReaderCopyAll(controller);
    await tester.pump();
    expect(find.text('This document has no text to copy'), findsOneWidget);
    expect(clipboard, isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
