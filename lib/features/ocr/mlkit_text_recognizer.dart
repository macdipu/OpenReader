import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;
import 'package:universal_document_viewer/ocr.dart';

/// OCR on Android through Google ML Kit's on-device Latin text recognizer
/// (CR-READER-SELECT-OCR SO-14). The model ships inside the app: nothing is
/// downloaded and nothing leaves the device.
///
/// ML Kit's Latin model reads Latin-script text only; it does not detect the
/// language, so [supportsAutoDetect] is false and language hints are not used
/// (the user decided on 2026-11-22 that only what the models support matters).
class MlKitTextRecognizer extends TextRecognizer {
  /// An Android recognizer; [available] is for tests.
  MlKitTextRecognizer({bool? available}) : _available = available ?? Platform.isAndroid;

  final bool _available;
  mlkit.TextRecognizer? _engine;

  @override
  bool get isAvailable => _available;

  @override
  Future<OcrResult> recognize(OcrInput input) async {
    final folder = await Directory.systemTemp.createTemp('openreader-ocr-');
    try {
      final file = File('${folder.path}/page.png');
      await file.writeAsBytes(input.png, flush: true);
      final engine = _engine ??= mlkit.TextRecognizer();
      final recognised = await engine.processImage(mlkit.InputImage.fromFilePath(file.path));
      return ocrResultFromMlKit(recognised);
    } finally {
      // The page image is the user's document content: never leave it behind.
      try {
        await folder.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Releases the native recognizer.
  Future<void> close() async {
    final engine = _engine;
    _engine = null;
    await engine?.close();
  }
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
