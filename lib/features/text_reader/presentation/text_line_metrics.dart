import 'package:flutter/painting.dart';

/// Scroll offsets of the text reader's rows, measured with the same style,
/// text scaling and width the rows render with, so jump-to-match lands on
/// the matching line instead of a fixed-height guess (CR-OPENREADER-UX
/// UX-21). Avoids a positioned-list dependency.
///
/// Wrapped rows are measured one by one and summed lazily, so a jump costs
/// layout only for lines not measured yet. Unwrapped rows are all one line
/// tall, so their offset is a multiplication.
class TextLineMetrics {
  TextLineMetrics({
    required this.lines,
    required this.style,
    required this.textScaler,
    required this.contentWidth,
    required this.wrap,
    required this.verticalPadding,
  });

  final List<String> lines;
  final TextStyle style;
  final TextScaler textScaler;

  /// Width available to a wrapped row's text (row width minus its padding).
  final double contentWidth;
  final bool wrap;

  /// A row's vertical padding (top + bottom).
  final double verticalPadding;

  /// `_offsets[i]` is the top of row `i`; grows as rows are measured.
  final List<double> _offsets = [0];

  late final double _singleRowHeight = _measure('', double.infinity) + verticalPadding;

  /// Whether this was measured for the same rows and layout inputs, i.e. its
  /// cached offsets are still valid.
  bool matches({
    required List<String> lines,
    required TextStyle style,
    required TextScaler textScaler,
    required double contentWidth,
    required bool wrap,
  }) =>
      identical(lines, this.lines) &&
      style == this.style &&
      textScaler == this.textScaler &&
      contentWidth == this.contentWidth &&
      wrap == this.wrap;

  double offsetOf(int lineIndex) {
    final index = lineIndex.clamp(0, lines.length);
    if (!wrap) return index * _singleRowHeight;
    while (_offsets.length <= index) {
      final row = _offsets.length - 1;
      _offsets.add(_offsets[row] + _measure(lines[row], contentWidth) + verticalPadding);
    }
    return _offsets[index];
  }

  double _measure(String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
