import 'dart:io';
import 'dart:ui' show PlatformDispatcher, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;
import 'package:universal_document_viewer/ocr.dart';

import 'ocr_progress.dart';

export 'ocr_progress.dart';

/// The scripts ML Kit can read, each with its own model bundled in the app.
enum OcrScript {
  latin(mlkit.TextRecognitionScript.latin),
  japanese(mlkit.TextRecognitionScript.japanese),
  chinese(mlkit.TextRecognitionScript.chinese),
  korean(mlkit.TextRecognitionScript.korean),
  devanagari(mlkit.TextRecognitionScript.devanagiri);

  const OcrScript(this.mlkitScript);

  final mlkit.TextRecognitionScript mlkitScript;

  /// The script a language is usually written in. Anything else, including every Latin-script
  /// language, is [latin]. It decides which script is read first and wins a tie.
  static OcrScript forLanguage(String? languageCode) => switch (languageCode?.toLowerCase()) {
    'ja' => japanese,
    'zh' => chinese,
    'ko' => korean,
    'hi' || 'mr' || 'ne' || 'sa' => devanagari,
    _ => latin,
  };
}

/// Reads a page image with one script's recognizer.
typedef ScriptRecognition = Future<OcrResult> Function(OcrScript script, String imagePath);

/// OCR on Android through Google ML Kit's on-device recognizers (CR-READER-SELECT-OCR SO-14). The models
/// for Latin, Japanese, Chinese, Korean and Devanagari text ship inside the app: nothing is downloaded
/// and nothing leaves the device.
///
/// ML Kit has one recognizer per script and cannot tell the scripts apart, and a page often mixes them (a
/// Japanese document with English words and numbers). So every page is read with every script and the
/// readings are merged: where two scripts read the same place, the more confident one wins, and the
/// device language's script wins a tie. Each script's recognizer also reads Latin text, so a Latin
/// page loses nothing.
///
/// [progress] carries what has been found after each script, so the page can show the reading as it
/// happens; it is null when no page is being read.
class MlKitTextRecognizer extends TextRecognizer {
  /// An Android recognizer. [available], [deviceLanguage] and [recognizeWith] are for tests.
  MlKitTextRecognizer({bool? available, String? Function()? deviceLanguage, ScriptRecognition? recognizeWith})
    : _available = available ?? Platform.isAndroid,
      _deviceLanguage = deviceLanguage ?? (() => PlatformDispatcher.instance.locale.languageCode),
      _recognizeWith = recognizeWith;

  final bool _available;
  final String? Function() _deviceLanguage;
  final ScriptRecognition? _recognizeWith;
  final _engines = <OcrScript, mlkit.TextRecognizer>{};

  /// What the reading in progress has found so far.
  final progress = ValueNotifier<OcrProgress?>(null);

  @override
  bool get isAvailable => _available;

  /// The order scripts are read and ranked in: [first] (the device language's), then the others.
  static List<OcrScript> order(OcrScript first) => [first, ...OcrScript.values.where((s) => s != first)];

  @override
  Future<OcrResult> recognize(OcrInput input) async {
    final folder = await Directory.systemTemp.createTemp('openreader-ocr-');
    try {
      final file = File('${folder.path}/page.png');
      await file.writeAsBytes(input.png, flush: true);
      final first = OcrScript.forLanguage(_deviceLanguage());
      final scripts = order(first);
      final imageSize = Size(input.width.toDouble(), input.height.toDouble());
      final readings = <OcrResult>[];
      progress.value = OcrProgress(done: 0, total: scripts.length, lines: const [], imageSize: imageSize);
      for (final script in scripts) {
        readings.add(await _read(script, file.path, keepEngine: script == first));
        progress.value = OcrProgress(
          done: readings.length,
          total: scripts.length,
          lines: mergeOcrResults(readings).lines,
          imageSize: imageSize,
        );
      }
      return mergeOcrResults(readings);
    } finally {
      progress.value = null;
      // The page image is the user's document content: never leave it behind.
      try {
        await folder.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<OcrResult> _read(OcrScript script, String imagePath, {required bool keepEngine}) async {
    final custom = _recognizeWith;
    if (custom != null) return custom(script, imagePath);
    final engine = _engines[script] ??= mlkit.TextRecognizer(script: script.mlkitScript);
    try {
      final recognised = await engine.processImage(mlkit.InputImage.fromFilePath(imagePath));
      return ocrResultFromMlKit(recognised);
    } finally {
      // Each model is tens of megabytes of native memory: only the main script's stays loaded.
      if (!keepEngine) {
        _engines.remove(script);
        await engine.close();
      }
    }
  }

  /// Releases the native recognizers.
  Future<void> close() async {
    final engines = _engines.values.toList();
    _engines.clear();
    for (final engine in engines) {
      await engine.close();
    }
    progress.dispose();
  }
}

/// Two lines read the same place when the overlap is more than this share of the smaller one.
const _sameLineOverlap = 0.5;

double _area(Rect r) => r.width * r.height;

bool _samePlace(Rect a, Rect b) {
  final overlap = a.intersect(b);
  if (overlap.width <= 0 || overlap.height <= 0) return false;
  final smaller = _area(a) < _area(b) ? _area(a) : _area(b);
  return smaller > 0 && _area(overlap) / smaller > _sameLineOverlap;
}

/// The readings of one page by several scripts as one result, in reading order. [readings] go in
/// priority order (the first wins a tie). A line that two readings both found is kept once, from the
/// more confident reading (a line with no confidence counts as 0.5); lines only one script found are all
/// kept. The language is the first one any reading named.
OcrResult mergeOcrResults(List<OcrResult> readings) {
  final kept = <OcrLine>[];
  for (final reading in readings) {
    for (final line in reading.lines) {
      if (line.text.trim().isEmpty) continue;
      final clash = kept.indexWhere((k) => _samePlace(k.rect, line.rect));
      if (clash < 0) {
        kept.add(line);
      } else if ((line.confidence ?? 0.5) > (kept[clash].confidence ?? 0.5)) {
        // Strictly more confident: an equal reading from a later script never replaces an earlier one.
        kept[clash] = line;
      }
    }
  }
  kept.sort((a, b) {
    final byTop = a.rect.top.compareTo(b.rect.top);
    return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
  });
  String? language;
  for (final reading in readings) {
    language ??= reading.detectedLanguage;
  }
  return OcrResult(lines: kept, detectedLanguage: language);
}

/// ML Kit's blocks and lines as the package's [OcrResult]: a line each, in
/// the order ML Kit gives them, with the most common language it named.
OcrResult ocrResultFromMlKit(mlkit.RecognizedText recognised) {
  final lines = <OcrLine>[];
  final languages = <String, int>{};
  for (final block in recognised.blocks) {
    for (final line in block.lines) {
      if (line.text.trim().isEmpty) continue;
      lines.add(OcrLine(text: line.text, rect: line.boundingBox, confidence: line.confidence));
      for (final language in line.recognizedLanguages) {
        // "und" is ML Kit's "undetermined".
        if (language != 'und') languages[language] = (languages[language] ?? 0) + 1;
      }
    }
  }
  String? best;
  languages.forEach((language, count) {
    if (best == null || count > languages[best]!) best = language;
  });
  return OcrResult(lines: lines, detectedLanguage: best);
}
