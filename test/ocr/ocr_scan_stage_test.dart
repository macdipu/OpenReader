import 'dart:convert';
import 'dart:ui' show Rect, Size;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/ocr/mlkit_text_recognizer.dart';
import 'package:openreader/features/ocr/presentation/ocr_scan_overlay.dart';
import 'package:universal_document_viewer/ocr.dart';

/// A 1x1 PNG: any valid image will do for the page preview.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _size = Size(1000, 1400);

OcrLine _line(String text, double top, {double? confidence = 0.9}) =>
    OcrLine(text: text, rect: Rect.fromLTWH(50, top, 600, 40), confidence: confidence);

OcrProgress _progress(List<OcrLine> lines, {int done = 1, bool image = true}) =>
    OcrProgress(done: done, total: 5, lines: lines, imageSize: _size, image: image ? _png : null);

void main() {
  group('the beam over the document moves row by row', () {
    const height = 2800.0;
    const rowHeight = height / OcrScanOverlay.rows;

    test('it starts at the top, ends at the bottom and never moves backwards', () {
      expect(ScanPainter.headY(0, height), 0);
      expect(ScanPainter.headY(1, height), closeTo(height, 0.001));
      var last = -1.0;
      for (var i = 0; i <= 1000; i++) {
        final y = ScanPainter.headY(i / 1000, height);
        expect(y, greaterThanOrEqualTo(last));
        last = y;
      }
    });

    test('inside each row it hops to the row\'s bottom quickly and then rests there', () {
      const rowShare = 1 / OcrScanOverlay.rows;
      // A fifth of the way into row 3: still hopping, somewhere between its top and bottom.
      final hopping = ScanPainter.headY(3 * rowShare + rowShare * 0.15, height);
      expect(hopping, greaterThan(3 * rowHeight));
      expect(hopping, lessThan(4 * rowHeight));
      // Most of the way through the row it has arrived and rests on the row's bottom edge.
      final resting = ScanPainter.headY(3 * rowShare + rowShare * 0.9, height);
      expect(resting, closeTo(4 * rowHeight, 0.001));
      expect(ScanPainter.headY(3 * rowShare + rowShare * 0.6, height), closeTo(resting, 0.001));
    });

    test('it takes a few seconds to read the page, not a blink', () {
      final seconds = (OcrScanOverlay.rowTime * OcrScanOverlay.rows).inMilliseconds / 1000;
      expect(seconds, inInclusiveRange(2, 5));
    });
  });

  group('the full-screen scan of a page', () {
    Future<ValueNotifier<OcrProgress?>> pumpScan(WidgetTester tester, {bool reduceMotion = false}) async {
      final progress = ValueNotifier<OcrProgress?>(null);
      addTearDown(progress.dispose);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: MaterialApp(
            home: Scaffold(
              // The scan fills the reader, as it does over the document.
              body: SizedBox(
                width: 420,
                height: 900,
                child: OcrScanStage(progress: progress, tick: const Duration(milliseconds: 100)),
              ),
            ),
          ),
        ),
      );
      return progress;
    }

    Future<void> hop(WidgetTester tester, [int times = 1]) async {
      for (var i = 0; i < times; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    testWidgets('the page is shown large, filling the width of the reader, not as a thumbnail', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress(const [], done: 0);
      await tester.pump();
      final page = tester.getSize(find.byKey(const Key('ocr-scan-preview')));
      expect(page.width, greaterThan(300), reason: 'most of the 420 wide reader');
      expect(page.height, greaterThan(page.width), reason: 'a portrait page keeps its shape');
      expect(page.width / page.height, closeTo(_size.width / _size.height, 0.01));
      expect(find.byKey(const Key('ocr-scan-stage')), findsOneWidget);
    });

    testWidgets('the stage covers the reader so the page behind cannot be scrolled while it is read', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress(const [], done: 0);
      await tester.pump();
      expect(find.descendant(of: find.byKey(const Key('ocr-scan-stage')), matching: find.byType(AbsorbPointer)), findsWidgets);
      final stage = tester.getSize(find.byKey(const Key('ocr-scan-stage')));
      expect(stage, const Size(420, 900));
    });

    testWidgets('nothing shows until a reading reports', (tester) async {
      await pumpScan(tester);
      expect(find.byKey(const Key('ocr-scan-preview')), findsNothing);
      expect(find.textContaining('found'), findsNothing);
    });

    testWidgets('the page preview shows with the scan head, and the count starts at Scanning', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress(const [], done: 0);
      await tester.pump();
      expect(find.byKey(const Key('ocr-scan-preview')), findsOneWidget);
      expect(find.text('Scanning…'), findsOneWidget);
      expect(find.byKey(const Key('ocr-line-box')), findsNothing);
    });

    testWidgets('lines are lit one at a time, top first, as the head reaches them', (tester) async {
      final progress = await pumpScan(tester);
      // Given out of order: the head still reads from the top of the page down.
      progress.value = _progress([_line('third', 900), _line('first', 100), _line('second', 500)]);
      await tester.pump();
      expect(find.byKey(const Key('ocr-line-box')), findsNothing, reason: 'the head has not moved yet');

      await hop(tester);
      expect(find.byKey(const Key('ocr-line-box')), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);
      expect(find.text('1 line found'), findsOneWidget);

      await hop(tester);
      expect(find.byKey(const Key('ocr-line-box')), findsNWidgets(2));
      expect(find.text('second'), findsOneWidget);
      expect(find.text('2 lines found'), findsOneWidget);

      await hop(tester);
      expect(find.byKey(const Key('ocr-line-box')), findsNWidgets(3));
      expect(find.text('3 lines found'), findsOneWidget);
    });

    testWidgets('lines that arrive later, from another script, are read in turn', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress([_line('Invoice 12345', 100)]);
      await hop(tester, 2);
      expect(find.text('1 line found'), findsOneWidget);

      progress.value = _progress([_line('Invoice 12345', 100), _line('請求書', 300)], done: 2);
      await hop(tester);
      expect(find.text('請求書'), findsOneWidget);
      expect(find.text('2 lines found'), findsOneWidget);
    });

    testWidgets('a better reading of the same place replaces the earlier one instead of adding a line', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress([_line('l1l 1ll', 100, confidence: 0.3)]);
      await hop(tester, 2);
      expect(find.text('l1l 1ll'), findsOneWidget);

      progress.value = _progress([_line('日本語', 100, confidence: 0.95)], done: 2);
      await hop(tester, 2);
      expect(find.byKey(const Key('ocr-line-box')), findsOneWidget, reason: 'same place, one box');
      expect(find.text('1 line found'), findsOneWidget);
      expect(find.text('日本語'), findsOneWidget);
      expect(find.text('l1l 1ll'), findsNothing);
    });

    testWidgets('only the latest few lines are listed, the count keeps going', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress([for (var i = 0; i < 7; i++) _line('line $i', 100.0 + i * 100)]);
      await hop(tester, 8);
      expect(find.text('7 lines found'), findsOneWidget);
      expect(find.text('line 6'), findsOneWidget);
      expect(find.text('line 0'), findsNothing, reason: 'scrolled out of the short list');
      expect(find.byKey(const Key('ocr-line-box')), findsNWidgets(7));
    });

    testWidgets('without a page image there is no preview, but the findings still stream', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress([_line('Scanned words', 100)], image: false);
      await hop(tester, 2);
      expect(find.byKey(const Key('ocr-scan-preview')), findsNothing);
      expect(find.text('Scanned words'), findsOneWidget);
      expect(find.text('1 line found'), findsOneWidget);
    });

    testWidgets('when the reading ends the scan clears, and a new reading starts from nothing', (tester) async {
      final progress = await pumpScan(tester);
      progress.value = _progress([_line('first page', 100)]);
      await hop(tester, 2);
      expect(find.text('first page'), findsOneWidget);

      progress.value = null;
      await tester.pump();
      expect(find.byKey(const Key('ocr-scan-preview')), findsNothing);

      progress.value = _progress([_line('next page', 100)], done: 1);
      await hop(tester, 2);
      expect(find.text('1 line found'), findsOneWidget);
      expect(find.text('next page'), findsOneWidget);
      expect(find.text('first page'), findsNothing);
    });

    testWidgets('with animations removed the lines still appear, without moving', (tester) async {
      final progress = await pumpScan(tester, reduceMotion: true);
      progress.value = _progress([_line('quiet', 100)]);
      await hop(tester, 2);
      expect(find.text('quiet'), findsOneWidget);
      expect(find.byKey(const Key('ocr-line-box')), findsOneWidget);
    });
  });
}
