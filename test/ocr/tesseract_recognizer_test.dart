import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/ocr/tesseract_text_recognizer.dart';
import 'package:universal_document_viewer/ocr.dart';

/// CR-READER-SELECT-OCR SO-14: the Linux Tesseract recognizer, with the
/// program replaced by a fake: the command line it builds and how it reads the
/// answer.
const _tsv =
    'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
    '1\t1\t0\t0\t0\t0\t0\t0\t800\t600\t-1\t\n'
    '4\t1\t1\t1\t1\t0\t10\t20\t200\t30\t-1\t\n'
    '5\t1\t1\t1\t1\t1\t10\t20\t90\t30\t96.5\tHello\n'
    '5\t1\t1\t1\t1\t2\t110\t22\t100\t28\t91.0\tworld\n'
    '4\t1\t1\t1\t2\t0\t10\t70\t150\t30\t-1\t\n'
    '5\t1\t1\t1\t2\t1\t10\t70\t150\t30\t88.0\tSecond\n'
    '5\t1\t1\t1\t2\t2\t170\t70\t10\t30\t-1\t   \n';

void main() {
  group('reading the program\'s output', () {
    test('lines are words grouped by line, with a box and mean confidence', () {
      final result = ocrResultFromTesseractTsv(_tsv, language: 'eng');
      expect(result.lines.map((l) => l.text), ['Hello world', 'Second']);
      expect(result.lines.first.rect, const Rect.fromLTRB(10, 20, 210, 50));
      expect(result.lines.first.confidence, closeTo(0.9375, 1e-9));
      expect(result.lines.last.rect, const Rect.fromLTRB(10, 70, 160, 100));
      expect(result.detectedLanguage, 'en');
    });

    test('empty output is no text; an unknown language keeps its code', () {
      expect(ocrResultFromTesseractTsv('').isEmpty, isTrue);
      expect(ocrResultFromTesseractTsv('', language: 'xyz').detectedLanguage, 'xyz');
      expect(ocrResultFromTesseractTsv('').detectedLanguage, isNull);
    });

    test('--list-langs output gives the installed languages', () {
      expect(
        parseTesseractLanguages('List of available languages (3):\neng\nosd\nben\n'),
        ['eng', 'ben'],
      );
      expect(parseTesseractLanguages('Error opening data file'), isEmpty);
    });
  });

  group('choosing the language', () {
    test('a hint that is installed wins, in either code form', () {
      expect(chooseTesseractLanguage(['bn'], ['eng', 'ben']), 'ben');
      expect(chooseTesseractLanguage(['de-DE'], ['eng', 'deu']), 'deu');
      expect(chooseTesseractLanguage(['ben'], ['eng', 'ben']), 'ben');
    });

    test('otherwise English, else the first installed', () {
      expect(chooseTesseractLanguage(['fr'], ['eng', 'deu']), 'eng');
      expect(chooseTesseractLanguage([], ['deu', 'fra']), 'deu');
      expect(chooseTesseractLanguage([], []), 'eng');
    });
  });

  group('TesseractTextRecognizer', () {
    OcrInput input({List<String> hints = const []}) =>
        OcrInput(png: Uint8List.fromList([1, 2, 3]), width: 800, height: 600, languageHints: hints);

    test('is available only with the program and at least one language', () {
      expect(TesseractTextRecognizer(languages: const ['eng'], available: true).isAvailable, isTrue);
      expect(TesseractTextRecognizer(languages: const [], available: true).isAvailable, isFalse);
      expect(TesseractTextRecognizer(languages: const ['eng'], available: false).isAvailable, isFalse);
      expect(TesseractTextRecognizer(languages: const ['eng'], available: true).supportsAutoDetect, isFalse);
    });

    test('runs the program on a temporary copy of the page, reads TSV, and deletes the copy', () async {
      late List<String> arguments;
      String? imageCopy;
      final recognizer = TesseractTextRecognizer(
        languages: const ['eng', 'ben'],
        available: true,
        run: (exe, args) async {
          arguments = args;
          imageCopy = args.first;
          expect(File(args.first).readAsBytesSync(), [1, 2, 3]);
          return ProcessResult(0, 0, _tsv, '');
        },
      );
      final result = await recognizer.recognize(input(hints: ['bn']));

      expect(arguments.sublist(1), ['stdout', '-l', 'ben', '--psm', '3', 'tsv']);
      expect(result.text, 'Hello world\nSecond');
      expect(result.detectedLanguage, 'bn');
      expect(File(imageCopy!).existsSync(), isFalse, reason: 'the page image must not be left behind');
    });

    test('a failing program throws, and still deletes the copy', () async {
      String? imageCopy;
      final recognizer = TesseractTextRecognizer(
        languages: const ['eng'],
        available: true,
        run: (exe, args) async {
          imageCopy = args.first;
          return ProcessResult(0, 1, '', 'Error opening data file');
        },
      );
      await expectLater(recognizer.recognize(input()), throwsA(isA<ProcessException>()));
      expect(File(imageCopy!).existsSync(), isFalse);
    });
  });
}
