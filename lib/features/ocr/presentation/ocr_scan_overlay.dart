import 'package:flutter/material.dart';
import 'package:universal_document_viewer/pdf.dart';

/// A scanner beam sweeping over the document while OCR reads the page in view: a soft trail behind a thin
/// glowing line, top to bottom, again and again. It sits over the viewer, passes touches through, and
/// shows only while the current page is being read. With "remove animations" on, it is a still tint
/// (CR-READER-SELECT-OCR SO-13).
class OcrScanOverlay extends StatefulWidget {
  const OcrScanOverlay({super.key, required this.controller});

  /// The open PDF; its current page decides when the beam shows.
  final PdfController controller;

  @override
  State<OcrScanOverlay> createState() => _OcrScanOverlayState();
}

class _OcrScanOverlayState extends State<OcrScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));

  PdfController get _pdf => widget.controller;
  bool get _reading => _pdf.canRecognize && _pdf.pageCount > 0 && _pdf.ocrStatusOf(_pdf.currentPage - 1) == PdfOcrStatus.running;

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
            painter: _BeamPainter(progress: Curves.easeInOut.transform(_sweep.value), color: color),
          ),
        ),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({required this.progress, required this.color});

  /// 0 (top) to 1 (bottom).
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    const trail = 140.0;
    final top = (y - trail).clamp(0.0, size.height);
    final area = Rect.fromLTRB(0, top, size.width, y);
    if (area.height > 0) {
      canvas.drawRect(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.22)],
          ).createShader(Rect.fromLTRB(0, y - trail, size.width, y)),
      );
    }
    // The glow, then the line itself.
    canvas.drawRect(
      Rect.fromLTWH(0, y - 3, size.width, 6),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BeamPainter old) => old.progress != progress || old.color != color;
}
