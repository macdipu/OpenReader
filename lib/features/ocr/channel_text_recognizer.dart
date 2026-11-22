import 'dart:io';

import 'package:flutter/services.dart';
import 'package:universal_document_viewer/ocr.dart';

/// OCR done by the operating system through a platform channel (CR-READER-
/// SELECT-OCR SO-14): Apple Vision on macOS and iOS (`macos/Runner/AppDelegate.swift`,
/// `ios/Runner/AppDelegate.swift`), Windows.Media.Ocr on Windows
/// (`windows/runner/ocr_channel.cpp`). Everything stays on the device.
///
/// The channel's `recognize` call takes `png` (bytes) and `languages` (codes,
/// possibly empty) and answers `{lines: [{text, left, top, right, bottom,
/// confidence}], language}` with boxes in image pixels from the top-left.
class ChannelTextRecognizer extends TextRecognizer {
  /// A recognizer talking over [channel]; [available] is for tests.
  ChannelTextRecognizer({
    MethodChannel channel = const MethodChannel('openreader/ocr'),
    bool? available,
    this.detectsLanguage = true,
  }) : _channel = channel,
       _available = available ?? (Platform.isMacOS || Platform.isIOS || Platform.isWindows);

  final MethodChannel _channel;
  final bool _available;

  /// Whether the native side works out the language itself (Vision does on
  /// macOS 13 and iOS 16 and later; it falls back to its default languages
  /// before). Windows does not: it uses the user's language packs.
  final bool detectsLanguage;

  @override
  bool get isAvailable => _available;

  @override
  bool get supportsAutoDetect => detectsLanguage;

  @override
  Future<OcrResult> recognize(OcrInput input) async {
    final reply = await _channel.invokeMapMethod<String, Object?>('recognize', {
      'png': input.png,
      'languages': input.languageHints,
    });
    return ocrResultFromChannel(reply ?? const {});
  }
}

/// The channel's reply as an [OcrResult]; lines with no text are dropped.
OcrResult ocrResultFromChannel(Map<String, Object?> reply) {
  final lines = <OcrLine>[];
  for (final raw in (reply['lines'] as List<Object?>? ?? const [])) {
    final line = Map<String, Object?>.from(raw! as Map);
    final text = (line['text'] as String? ?? '').trim();
    if (text.isEmpty) continue;
    double number(String key) => (line[key] as num?)?.toDouble() ?? 0;
    lines.add(
      OcrLine(
        text: text,
        rect: Rect.fromLTRB(number('left'), number('top'), number('right'), number('bottom')),
        confidence: (line['confidence'] as num?)?.toDouble(),
      ),
    );
  }
  final language = reply['language'] as String?;
  return OcrResult(lines: lines, detectedLanguage: (language == null || language.isEmpty) ? null : language);
}
