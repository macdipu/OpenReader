import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/ocr/mlkit_text_recognizer.dart';
import 'package:universal_document_viewer/ocr.dart';

OcrLine line(String value, {double top = 0, double left = 0, double? confidence = 0.9, double width = 200, double height = 20}) =>
    OcrLine(text: value, rect: Rect.fromLTWH(left, top, width, height), confidence: confidence);

OcrResult page(List<OcrLine> lines, {String? language}) => OcrResult(lines: lines, detectedLanguage: language);

final input = OcrInput(png: Uint8List.fromList([1, 2, 3]), width: 1, height: 1);

void main() {
  group('which script a language uses', () {
    test('Japanese, Chinese, Korean and the Devanagari languages have their own; everything else is Latin', () {
      expect(OcrScript.forLanguage('ja'), OcrScript.japanese);
      expect(OcrScript.forLanguage('zh'), OcrScript.chinese);
      expect(OcrScript.forLanguage('ko'), OcrScript.korean);
      for (final code in ['hi', 'mr', 'ne', 'sa']) {
        expect(OcrScript.forLanguage(code), OcrScript.devanagari, reason: code);
      }
      for (final code in ['en', 'bn', 'fr', 'de', 'es', 'ar', '', null]) {
        expect(OcrScript.forLanguage(code), OcrScript.latin, reason: '$code');
      }
      expect(OcrScript.forLanguage('JA'), OcrScript.japanese);
    });

    test('the order starts with the preferred script and has every script once', () {
      for (final first in OcrScript.values) {
        final order = MlKitTextRecognizer.order(first);
        expect(order.first, first);
        expect(order.toSet(), OcrScript.values.toSet());
        expect(order, hasLength(OcrScript.values.length));
      }
    });
  });

  group('merging the readings of several scripts', () {
    test('lines only one script found are all kept, top to bottom', () {
      final merged = mergeOcrResults([
        page([line('Invoice 2026', top: 0)]),
        page([line('請求書', top: 100)]),
        page([line('합계', top: 50)]),
      ]);
      expect(merged.lines.map((l) => l.text), ['Invoice 2026', '합계', '請求書']);
    });

    test('a line two scripts both read is kept once, from the more confident one', () {
      final merged = mergeOcrResults([
        page([line('l1l 1ll', confidence: 0.35)]), // Latin guessing at Japanese
        page([line('日本語', confidence: 0.95)]),
      ]);
      expect(merged.lines.map((l) => l.text), ['日本語']);
    });

    test('Latin text read by every script appears once, and the first script wins an equal reading', () {
      final merged = mergeOcrResults([
        page([line('Total: 1,250.00', confidence: 0.9)]),
        page([line('Total: 1,250.00 ', confidence: 0.9)]),
        page([line('Total 1250', confidence: 0.9)]),
      ]);
      expect(merged.lines.map((l) => l.text), ['Total: 1,250.00']);
    });

    test('a line with no confidence counts half, so a sure reading beats it', () {
      final merged = mergeOcrResults([
        page([line('maybe', confidence: null)]),
        page([line('sure', confidence: 0.8)]),
      ]);
      expect(merged.lines.single.text, 'sure');
    });

    test('lines that touch but do not overlap much are both kept', () {
      final merged = mergeOcrResults([
        page([line('first', top: 0, height: 20)]),
        page([line('second', top: 19, height: 20)]),
      ]);
      expect(merged.lines, hasLength(2));
    });

    test('blank lines are dropped, nothing at all is nothing, and the first language named is kept', () {
      expect(mergeOcrResults([page([line('  ')]), OcrResult.empty]).lines, isEmpty);
      expect(mergeOcrResults([]).lines, isEmpty);
      expect(mergeOcrResults([page([line('a')]), page([line('b', top: 50)], language: 'ja')]).detectedLanguage, 'ja');
    });
  });

  group('reading a page', () {
    test('every script reads every page, the device language first, and the readings are merged', () async {
      final tried = <OcrScript>[];
      final recognizer = MlKitTextRecognizer(
        available: true,
        deviceLanguage: () => 'en',
        recognizeWith: (script, _) async {
          tried.add(script);
          return switch (script) {
            OcrScript.latin => page([line('Add a language', top: 0)]),
            OcrScript.japanese => page([line('日本語', top: 100)]),
            OcrScript.korean => page([line('한국어', top: 50)]),
            _ => OcrResult.empty,
          };
        },
      );
      final result = await recognizer.recognize(input);
      expect(tried, MlKitTextRecognizer.order(OcrScript.latin));
      expect(result.lines.map((l) => l.text), ['Add a language', '한국어', '日本語']);
    });

    test('a phone set to Japanese reads Japanese first, and still reads the other scripts', () async {
      final tried = <OcrScript>[];
      final recognizer = MlKitTextRecognizer(
        available: true,
        deviceLanguage: () => 'ja',
        recognizeWith: (script, _) async {
          tried.add(script);
          return OcrResult.empty;
        },
      );
      await recognizer.recognize(input);
      expect(tried.first, OcrScript.japanese);
      expect(tried.toSet(), OcrScript.values.toSet());
    });

    test('progress is reported after each script, with the lines merged so far, and cleared at the end', () async {
      final recognizer = MlKitTextRecognizer(
        available: true,
        deviceLanguage: () => 'en',
        recognizeWith: (script, _) async => switch (script) {
          OcrScript.latin => page([line('Add a language', top: 0)]),
          OcrScript.japanese => page([line('日本語', top: 100)]),
          _ => OcrResult.empty,
        },
      );
      final seen = <String>[];
      recognizer.progress.addListener(() {
        final p = recognizer.progress.value;
        seen.add(p == null ? 'done' : '${p.done}/${p.total}:${p.lines.length}');
      });

      await recognizer.recognize(OcrInput(png: Uint8List.fromList([1]), width: 800, height: 1200));

      expect(seen, ['0/5:0', '1/5:1', '2/5:2', '3/5:2', '4/5:2', '5/5:2', 'done']);
      expect(recognizer.progress.value, isNull);
    });

    test('progress knows the size of the image the line boxes are in', () async {
      final recognizer = MlKitTextRecognizer(
        available: true,
        deviceLanguage: () => 'en',
        recognizeWith: (script, _) async => OcrResult.empty,
      );
      Size? size;
      recognizer.progress.addListener(() => size ??= recognizer.progress.value?.imageSize);
      await recognizer.recognize(OcrInput(png: Uint8List.fromList([1]), width: 800, height: 1200));
      expect(size, const Size(800, 1200));
    });

    test('a page with no text returns nothing', () async {
      final recognizer = MlKitTextRecognizer(
        available: true,
        deviceLanguage: () => 'en',
        recognizeWith: (script, _) async => OcrResult.empty,
      );
      expect((await recognizer.recognize(input)).lines, isEmpty);
    });
  });
}
