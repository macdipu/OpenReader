import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/ocr/ocr_progress.dart';
import 'package:openreader/features/ocr/progress_reporting_recognizer.dart';
import 'package:universal_document_viewer/ocr.dart';

class _Inner extends TextRecognizer {
  _Inner({this.result = OcrResult.empty, this.fail = false, this.available = true, this.autoDetect = false, this.gate});

  final OcrResult result;
  final bool fail;
  final bool available;
  final bool autoDetect;
  final Completer<void>? gate;
  var calls = 0;

  @override
  bool get isAvailable => available;

  @override
  bool get supportsAutoDetect => autoDetect;

  @override
  Future<OcrResult> recognize(OcrInput input) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('engine failed');
    return result;
  }
}

final _input = OcrInput(png: Uint8List.fromList([1, 2, 3]), width: 800, height: 1200);

OcrResult _lines(int n) => OcrResult(
  lines: [for (var i = 0; i < n; i++) OcrLine(text: 'line $i', rect: Rect.fromLTWH(0, i * 30.0, 100, 20))],
  detectedLanguage: 'en',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('it reads like the wrapped engine and says what the engine says about itself', () {
    expect(ProgressReportingRecognizer(_Inner(available: true, autoDetect: true)).isAvailable, isTrue);
    expect(ProgressReportingRecognizer(_Inner(available: false)).isAvailable, isFalse);
    expect(ProgressReportingRecognizer(_Inner(autoDetect: true)).supportsAutoDetect, isTrue);
    expect(ProgressReportingRecognizer(_Inner()).supportsAutoDetect, isFalse);
  });

  test('the result is the engine\'s, unchanged', () async {
    final result = _lines(3);
    final wrapped = ProgressReportingRecognizer(_Inner(result: result), revealPerLine: Duration.zero);
    expect(identical(await wrapped.recognize(_input), result), isTrue);
  });

  test('progress starts empty with the size of the page, then holds the lines found, then clears', () async {
    final gate = Completer<void>();
    final wrapped = ProgressReportingRecognizer(
      _Inner(result: _lines(2), gate: gate),
      revealPerLine: const Duration(milliseconds: 10),
    );
    final seen = <String>[];
    wrapped.progress.addListener(() {
      final p = wrapped.progress.value;
      seen.add(p == null ? 'done' : '${p.done}/${p.total}:${p.lines.length}:${p.imageSize}');
    });

    final reading = wrapped.recognize(_input);
    await Future<void>.delayed(Duration.zero);
    expect(wrapped.progress.value?.lines, isEmpty, reason: 'reading, nothing found yet');
    expect(wrapped.progress.value?.imageSize, const Size(800, 1200));

    gate.complete();
    await reading;
    expect(seen, ['0/1:0:Size(800.0, 1200.0)', '1/1:2:Size(800.0, 1200.0)', 'done']);
    expect(wrapped.progress.value, isNull);
  });

  test('the result is held back so the scan can show the lines, a little for each, up to a limit', () async {
    final wrapped = ProgressReportingRecognizer(
      _Inner(result: _lines(100)),
      revealPerLine: const Duration(milliseconds: 20),
      maxReveal: const Duration(milliseconds: 120),
    );
    final watch = Stopwatch()..start();
    await wrapped.recognize(_input);
    expect(watch.elapsedMilliseconds, inInclusiveRange(100, 600), reason: '100 lines would be 2 s; the limit is 120 ms');

    final none = ProgressReportingRecognizer(_Inner(), revealPerLine: const Duration(milliseconds: 500));
    final quick = Stopwatch()..start();
    await none.recognize(_input);
    expect(quick.elapsedMilliseconds, lessThan(200), reason: 'a page with no lines is not held');
  });

  test('when the engine fails, the error is passed on and the progress is cleared', () async {
    final wrapped = ProgressReportingRecognizer(_Inner(fail: true));
    await expectLater(wrapped.recognize(_input), throwsStateError);
    expect(wrapped.progress.value, isNull);
  });
}
