import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;
import 'package:openreader/features/ocr/mlkit_text_recognizer.dart';
import 'package:openreader/features/ocr/ocr_recognizers.dart';
import 'package:openreader/features/ocr/presentation/ocr_page_banner.dart';
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
    Future<PdfController> open(WidgetTester tester, TextRecognizer? recognizer) async {
      final controller = PdfController(textRecognizer: recognizer);
      addTearDown(() => tester.runAsync(() async => controller.dispose()));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                PdfView(controller: controller),
                Align(alignment: Alignment.topCenter, child: OcrPageBanner(controller: controller)),
              ],
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
