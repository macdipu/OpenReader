import 'dart:async';
import 'dart:ui' show PlatformDispatcher, Size;

import 'package:flutter/foundation.dart';
import 'package:universal_document_viewer/ocr.dart';

import 'ocr_progress.dart';

/// Gives an engine that reads a page in one go (Apple Vision, Windows' OCR, Tesseract) the same live scan as
/// ML Kit's (CR-READER-SELECT-OCR SO-13): when it is done, the lines it found are published and the result is
/// held back for a moment, so the scan over the page can show them one by one before the selectable text takes
/// over. The recognition itself is the wrapped engine's, unchanged.
class ProgressReportingRecognizer extends TextRecognizer {
  /// Wraps [inner]. After a read, the result waits [revealPerLine] for each line found, up to [maxReveal].
  ProgressReportingRecognizer(
    this.inner, {
    this.revealPerLine = const Duration(milliseconds: 40),
    this.maxReveal = const Duration(milliseconds: 1300),
  });

  /// The engine that reads.
  final TextRecognizer inner;

  /// How long the scan gets to show each line found.
  final Duration revealPerLine;

  /// The most it holds a result back.
  final Duration maxReveal;

  /// What the reading in progress has found so far; null when no page is being read.
  final progress = ValueNotifier<OcrProgress?>(null);

  @override
  bool get isAvailable => inner.isAvailable;

  @override
  bool get supportsAutoDetect => inner.supportsAutoDetect;

  @override
  Future<OcrResult> recognize(OcrInput input) async {
    final size = Size(input.width.toDouble(), input.height.toDouble());
    progress.value = OcrProgress(done: 0, total: 1, lines: const [], imageSize: size);
    try {
      final result = await inner.recognize(input);
      progress.value = OcrProgress(done: 1, total: 1, lines: result.lines, imageSize: size);
      final hold = _hold(result.lines.length);
      if (hold > Duration.zero) await Future<void>.delayed(hold);
      return result;
    } finally {
      progress.value = null;
    }
  }

  Duration _hold(int lines) {
    // With "remove animations" on, nothing is played back: do not make the user wait for it.
    if (PlatformDispatcher.instance.accessibilityFeatures.disableAnimations) return Duration.zero;
    final wanted = revealPerLine * lines;
    return wanted > maxReveal ? maxReveal : wanted;
  }
}
