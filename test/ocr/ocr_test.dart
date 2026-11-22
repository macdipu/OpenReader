import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;
import 'package:openreader/features/ocr/mlkit_text_recognizer.dart';
import 'package:openreader/features/ocr/ocr_recognizers.dart';
import 'package:openreader/features/ocr/presentation/ocr_page_banner.dart';
import 'package:openreader/features/ocr/presentation/ocr_scan_overlay.dart';
import 'package:universal_document_viewer/pdf.dart';

/// CR-READER-SELECT-OCR SO-13 / SO-14: the OCR engine wrapper and the banner
/// that offers OCR on a page with no text.
const _scanFixture = 'test/fixtures/features_scan.pdf'; // page 4 has no text

class _Fake extends TextRecognizer {
  _Fake({this.lines = const [], this.fail = false, this.gate});

  final List<OcrLine> lines;
  final bool fail;
  final Completer<void>? gate;
  var calls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<OcrResult> recognize(OcrInput input) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('no model');
    return OcrResult(lines: lines);
  }
}

mlkit.TextLine _line(String text, Rect box, {double? confidence, List<String> languages = const ['en']}) =>
    mlkit.TextLine(
      text: text,
      elements: const [],
      boundingBox: box,
      recognizedLanguages: languages,
      cornerPoints: const [],
      confidence: confidence,
      angle: null,
    );

mlkit.TextBlock _block(List<mlkit.TextLine> lines) => mlkit.TextBlock(
  text: lines.map((l) => l.text).join('\n'),
  lines: lines,
  boundingBox: Rect.zero,
  recognizedLanguages: const [],
  cornerPoints: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(OcrRecognizers.debugReset);

  group('ML Kit wrapper', () {
    test('lines come out in ML Kit\'s order with their boxes and confidence', () {
      final result = ocrResultFromMlKit(
        mlkit.RecognizedText(
          text: 'a\nb\nc',
          blocks: [
            _block([_line('first', const Rect.fromLTWH(0, 0, 100, 20), confidence: 0.9)]),
            _block([
              _line('second', const Rect.fromLTWH(0, 30, 120, 20)),
              _line('  ', const Rect.fromLTWH(0, 60, 10, 20)),
            ]),
          ],
        ),
      );
      expect(result.lines.map((l) => l.text), ['first', 'second']);
      expect(result.lines.first.rect, const Rect.fromLTWH(0, 0, 100, 20));
      expect(result.lines.first.confidence, 0.9);
      expect(result.lines.last.confidence, isNull);
    });

    test('the language is the most common one ML Kit named, never "und"', () {
      final result = ocrResultFromMlKit(
        mlkit.RecognizedText(
          text: '',
          blocks: [
            _block([
              _line('a', Rect.zero, languages: const ['und']),
              _line('b', Rect.zero, languages: const ['fr']),
              _line('c', Rect.zero, languages: const ['fr']),
              _line('d', Rect.zero),
            ]),
          ],
        ),
      );
      expect(result.detectedLanguage, 'fr');
      expect(ocrResultFromMlKit(mlkit.RecognizedText(text: '', blocks: [])).detectedLanguage, isNull);
    });

    test('it runs only where ML Kit does, and does not claim to detect language', () {
      expect(MlKitTextRecognizer(available: false).isAvailable, isFalse);
      expect(MlKitTextRecognizer(available: true).isAvailable, isTrue);
      expect(MlKitTextRecognizer(available: true).supportsAutoDetect, isFalse);
    });

    test('off Android the platform has no recognizer', () {
      expect(OcrRecognizers.platform(), isNull);
    });
  });

  group('OcrPageBanner', () {
    Future<PdfController> open(
      WidgetTester tester,
      TextRecognizer? recognizer, {
      ValueNotifier<OcrProgress?>? progress,
      bool reduceMotion = false,
    }) async {
      final controller = PdfController(textRecognizer: recognizer);
      addTearDown(() => tester.runAsync(() async => controller.dispose()));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  PdfView(controller: controller),
                  Positioned.fill(child: OcrScanOverlay(controller: controller, progress: progress)),
                  Align(
                    alignment: Alignment.topCenter,
                    child: OcrPageBanner(controller: controller, progress: progress),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => controller.loadFile(_scanFixture));
      for (var i = 0; i < 100 && controller.status != DocumentStatus.ready; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump();
      await tester.pump();
      return controller;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
    }

    testWidgets('a page with text shows nothing', (tester) async {
      await open(tester, _Fake());
      await settle(tester);
      expect(find.text('Extract text'), findsNothing);
    });

    testWidgets('a page that is a picture offers Extract text, reads it, then goes quiet', (tester) async {
      final fake = _Fake(lines: const [OcrLine(text: 'Scanned words', rect: Rect.fromLTWH(10, 10, 300, 40))]);
      final controller = await open(tester, fake);
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      expect(controller.currentPage, 4);
      expect(find.text('Extract text'), findsOneWidget);

      await tester.tap(find.text('Extract text'));
      await settle(tester);
      expect(fake.calls, 1);
      expect(controller.ocrStatusOf(3), PdfOcrStatus.done);
      expect(find.text('Extract text'), findsNothing);
      expect(await tester.runAsync(controller.allText), contains('Scanned words'));
    });

    testWidgets('while reading it shows progress and Cancel', (tester) async {
      final gate = Completer<void>();
      final controller = await open(tester, _Fake(gate: gate));
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      await tester.tap(find.text('Extract text'));
      await settle(tester);
      expect(find.text('Reading the text on this page…'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      gate.complete();
      await settle(tester);
      expect(controller.ocrStatusOf(3), PdfOcrStatus.idle);
      expect(find.text('Extract text'), findsOneWidget, reason: 'offered again');
    });

    testWidgets('while reading, a scan beam sweeps the document; before and after it is gone', (tester) async {
      final gate = Completer<void>();
      final controller = await open(tester, _Fake(gate: gate));
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      expect(find.byKey(const Key('ocr-scan-beam')), findsNothing, reason: 'nothing is being read yet');

      await tester.tap(find.text('Extract text'));
      await settle(tester);
      expect(find.byKey(const Key('ocr-scan-beam')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('ocr-scan-beam')), findsOneWidget, reason: 'it keeps sweeping');

      gate.complete();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300)); // the scan fades out
      expect(find.byKey(const Key('ocr-scan-beam')), findsNothing);
    });

    testWidgets('with animations removed the beam is a still tint', (tester) async {
      final gate = Completer<void>();
      final controller = await open(tester, _Fake(gate: gate), reduceMotion: true);
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      await tester.tap(find.text('Extract text'));
      await settle(tester);
      expect(find.byKey(const Key('ocr-scan-beam')), findsNothing);
      expect(find.byKey(const Key('ocr-scan-still')), findsOneWidget);
      gate.complete();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('ocr-scan-still')), findsNothing);
    });

    testWidgets('the lines found pop up as tags beside the beam, one at a time, top first; the banner counts them', (tester) async {
      final gate = Completer<void>();
      final progress = ValueNotifier<OcrProgress?>(null);
      final controller = await open(tester, _Fake(gate: gate), progress: progress);
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      await tester.tap(find.text('Extract text'));
      await settle(tester);
      expect(find.byKey(const Key('ocr-found-tag')), findsNothing, reason: 'nothing found yet');
      expect(find.textContaining('lines found'), findsNothing);

      const size = Size(1000, 1000);
      progress.value = const OcrProgress(
        done: 1,
        total: 5,
        lines: [
          OcrLine(text: 'Second line', rect: Rect.fromLTWH(0, 300, 100, 20)),
          OcrLine(text: 'First line', rect: Rect.fromLTWH(0, 100, 100, 20)),
        ],
        imageSize: size,
      );
      await tester.pump();
      expect(find.text('2 lines found'), findsOneWidget, reason: 'the banner counts what the reading found');

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const Key('ocr-found-tag')), findsOneWidget);
      expect(find.text('First line'), findsOneWidget, reason: 'top of the page first');
      expect(find.text('Second line'), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const Key('ocr-found-tag')), findsNWidgets(2));
      expect(find.text('Second line'), findsOneWidget);

      gate.complete();
      await settle(tester);
    });

    testWidgets('a tag goes away after its time, and a long page keeps only the latest few up', (tester) async {
      final gate = Completer<void>();
      final progress = ValueNotifier<OcrProgress?>(null);
      final controller = await open(tester, _Fake(gate: gate), progress: progress);
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      await tester.tap(find.text('Extract text'));
      await settle(tester);

      progress.value = OcrProgress(
        done: 1,
        total: 5,
        lines: [for (var i = 0; i < 6; i++) OcrLine(text: 'line $i', rect: Rect.fromLTWH(0, 100.0 + i * 100, 100, 20))],
        imageSize: const Size(1000, 1000),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byKey(const Key('ocr-found-tag')).evaluate().length, lessThanOrEqualTo(OcrScanOverlay.maxTags));
      expect(find.text('6 lines found'), findsOneWidget);

      // Nothing new is coming: the tags fade and are taken down.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byKey(const Key('ocr-found-tag')), findsNothing);

      gate.complete();
      await settle(tester);
    });

    testWidgets('the scan lets touches through, so the page can still be scrolled while it is read', (tester) async {
      final gate = Completer<void>();
      final controller = await open(tester, _Fake(gate: gate));
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      await tester.tap(find.text('Extract text'));
      await settle(tester);
      expect(find.byKey(const Key('ocr-scan-beam')), findsOneWidget);
      final overlay = find.ancestor(of: find.byKey(const Key('ocr-scan-beam')), matching: find.byType(IgnorePointer));
      expect(overlay, findsWidgets);
      gate.complete();
      await settle(tester);
    });

    testWidgets('a failed read says so and offers Try again', (tester) async {
      final controller = await open(tester, _Fake(fail: true));
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      await tester.tap(find.text('Extract text'));
      await settle(tester);
      expect(find.text('Could not read the text on this page'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('with no recognizer there is no banner at all', (tester) async {
      final controller = await open(tester, null);
      unawaited(controller.jumpToPage(4));
      await settle(tester);
      expect(find.text('Extract text'), findsNothing);
      expect(find.byType(Material).evaluate().where((e) => e.widget is Material && (e.widget as Material).elevation == 3), isEmpty);
    });
  });
}
