import 'package:flutter/foundation.dart';
import 'package:universal_document_viewer/ocr.dart';

import 'channel_text_recognizer.dart';
import 'mlkit_text_recognizer.dart';
import 'tesseract_text_recognizer.dart';

/// The OCR engine for this platform (CR-READER-SELECT-OCR SO-14): ML Kit on
/// Android, Apple Vision on macOS and iOS, Windows.Media.Ocr on Windows, the system's Tesseract on Linux. Null where there is
/// none, so the readers show no OCR at all.
abstract final class OcrRecognizers {
  static TextRecognizer? _platform;
  static bool _resolved = false;

  /// For tests: use [recognizer] (or none, when null) instead of the
  /// platform's.
  @visibleForTesting
  static void debugOverride(TextRecognizer? recognizer) {
    _platform = recognizer;
    _resolved = true;
  }

  /// Forgets any override, so the platform's engine is picked again.
  @visibleForTesting
  static void debugReset() {
    _platform = null;
    _resolved = false;
  }

  /// The recognizer to give a reader, or null when this platform has none.
  static TextRecognizer? platform() {
    if (_resolved) return _platform;
    _resolved = true;
    if (!kIsWeb) {
      final recognizer = switch (defaultTargetPlatform) {
        TargetPlatform.android => MlKitTextRecognizer(),
        TargetPlatform.macOS || TargetPlatform.iOS => ChannelTextRecognizer(),
        TargetPlatform.windows => ChannelTextRecognizer(detectsLanguage: false),
        TargetPlatform.linux => TesseractTextRecognizer(),
        _ => null,
      };
      if (recognizer != null && recognizer.isAvailable) _platform = recognizer;
    }
    return _platform;
  }
}
