import 'package:flutter/material.dart';

/// One line of [text] that, when too long, keeps its start and end and drops the middle
/// ("/Users/me/…/scratchpad/samples"), so a path keeps both its root and its folder.
class MiddleEllipsisText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MiddleEllipsisText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final shown = middleTruncate(text, constraints.maxWidth, (candidate) {
        final painter = TextPainter(
          text: TextSpan(text: candidate, style: effective),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });
      return Text(shown, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.clip);
    });
  }
}

/// [text] cut in the middle to the longest form whose [measure] fits [maxWidth].
String middleTruncate(String text, double maxWidth, double Function(String) measure) {
  if (!maxWidth.isFinite || measure(text) <= maxWidth) return text;
  String cut(int keep) {
    final head = (keep / 2).ceil();
    final tail = keep - head;
    return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
  }

  var low = 0;
  var high = text.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (measure(cut(mid)) <= maxWidth) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return cut(low);
}
