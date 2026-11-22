import 'package:flutter/material.dart';
import 'package:universal_document_viewer/pdf.dart';

/// A scanner reading the document while OCR reads the page in view: it moves down the page row by row, in
/// quick hops with a short rest on each, lighting the row it is on, laying fine scan-lines behind it and
/// tinting what it has passed. It sits over the viewer, passes touches through, and shows only while the
/// current page is being read. With "remove animations" on, it is a still tint (CR-READER-SELECT-OCR SO-13).
class OcrScanOverlay extends StatefulWidget {
  const OcrScanOverlay({super.key, required this.controller});

  /// The open PDF; its current page decides when the scan shows.
  final PdfController controller;

  /// How many rows the page is read in, top to bottom, per sweep.
  static const rows = 28;

  /// How long the scan takes over one row (the hop and the rest).
  static const rowTime = Duration(milliseconds: 110);

  @override
  State<OcrScanOverlay> createState() => _OcrScanOverlayState();
}

class _OcrScanOverlayState extends State<OcrScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: OcrScanOverlay.rowTime * OcrScanOverlay.rows,
  );

  PdfController get _pdf => widget.controller;
  bool get _reading =>
      _pdf.canRecognize && _pdf.pageCount > 0 && _pdf.ocrStatusOf(_pdf.currentPage - 1) == PdfOcrStatus.running;

  @override
  void initState() {
    super.initState();
    _pdf.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(OcrScanOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      _pdf.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _pdf.removeListener(_onChanged);
    _sweep.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_reading) {
      if (_sweep.isAnimating) _sweep.stop();
      return const SizedBox.shrink();
    }
    final color = Theme.of(context).colorScheme.primary;
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_sweep.isAnimating) _sweep.stop();
      return IgnorePointer(child: ColoredBox(key: const Key('ocr-scan-still'), color: color.withValues(alpha: 0.06)));
    }
    if (!_sweep.isAnimating) _sweep.repeat();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) => CustomPaint(
            key: const Key('ocr-scan-beam'),
            size: Size.infinite,
            painter: ScanPainter(sweep: _sweep.value, color: color),
          ),
        ),
      ),
    );
  }
}

/// Paints the scan at [sweep] (0 at the top of the page, 1 at the bottom).
class ScanPainter extends CustomPainter {
  ScanPainter({required this.sweep, required this.color});

  final double sweep;
  final Color color;

  /// How much of each row's time the head spends hopping; the rest it rests.
  static const _hopShare = 0.38;

  /// Where the head is, in pixels from the top: it hops to the bottom of each row, then rests there.
  static double headY(double sweep, double height) {
    final rowHeight = height / OcrScanOverlay.rows;
    final position = sweep.clamp(0.0, 1.0) * OcrScanOverlay.rows;
    final row = position.floor();
    final into = position - row;
    final hop = Curves.easeOutCubic.transform((into / _hopShare).clamp(0.0, 1.0));
    return (row + hop) * rowHeight;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final rowHeight = size.height / OcrScanOverlay.rows;
    final y = headY(sweep, size.height);

    // What the scan has passed this round is tinted.
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, y), Paint()..color = color.withValues(alpha: 0.045));

    // Fine scan-lines behind the head, fading with distance.
    const trail = 150.0;
    final line = Paint()..strokeWidth = 1;
    for (var dy = 3.0; dy < trail; dy += 4) {
      final lineY = y - dy;
      if (lineY < 0) break;
      line.color = color.withValues(alpha: 0.22 * (1 - dy / trail));
      canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), line);
    }

    // The row being read is lit.
    final row = Rect.fromLTRB(0, (y - rowHeight).clamp(0.0, size.height), size.width, y);
    if (row.height > 0) {
      canvas.drawRect(
        row,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.02), color.withValues(alpha: 0.2)],
          ).createShader(row),
      );
    }

    // The head: a glow, then the line itself.
    canvas.drawRect(
      Rect.fromLTWH(0, y - 3, size.width, 6),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), Paint()..color = color);
  }

  @override
  bool shouldRepaint(ScanPainter old) => old.sweep != sweep || old.color != color;
}
