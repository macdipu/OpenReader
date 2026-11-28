import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:universal_document_viewer/ocr.dart';
import 'package:universal_document_viewer/pdf.dart';

import '../ocr_progress.dart';
import '../ocr_recognizers.dart';

/// The scan drawn on the page itself while OCR reads it (CR-READER-SELECT-OCR SO-13): a scan head that hops from
/// one line of text to the next, lighting each line exactly where it is on the page as it is read, with fine
/// scan-lines behind it and a tint over what it has passed. It is handed to the viewer as its page overlay
/// (`PdfView.pageOverlayBuilder`), so it fills the page's own box: it stays on the page as the page scrolls and
/// zooms, covers only the page, and looks the same on a phone and on a desktop window. It takes no touches.
///
/// The recognizer reports what it has found as it goes; this plays those findings back one line every [tick],
/// top of the page first, so the reading is seen line by line. While nothing new is waiting, the head keeps
/// stepping down the page. It shows only while [page] is being read. With "remove animations" on, nothing moves:
/// the page is tinted and the lines appear lit.
class OcrScanOverlay extends StatefulWidget {
  const OcrScanOverlay({
    super.key,
    required this.controller,
    required this.page,
    this.progress,
    this.tick = const Duration(milliseconds: 140),
  });

  /// The open PDF; its OCR status for [page] decides when the scan shows.
  final PdfController controller;

  /// Zero-based index of the page this overlay is on.
  final int page;

  /// What the reading has found so far; the platform engine's when null.
  final ValueListenable<OcrProgress?>? progress;

  /// How long the head rests on a line before the next one.
  final Duration tick;

  /// A backlog of lines is played back in about this many hops, so a full page takes seconds.
  static const backlogHops = 8;

  @override
  State<OcrScanOverlay> createState() => _OcrScanOverlayState();
}

class _OcrScanOverlayState extends State<OcrScanOverlay> {
  /// The lines the head has read, in the order it reached them. A later, better reading of the same place
  /// replaces the earlier one.
  final _revealed = <OcrLine>[];
  final _seen = <String>{};

  /// Where the head is, 0 (top) to 1 (bottom) of the page.
  double _head = 0;
  Timer? _timer;

  PdfController get _pdf => widget.controller;
  ValueListenable<OcrProgress?> get _progress => widget.progress ?? OcrRecognizers.progress;
  bool get _reading => _pdf.canRecognize && _pdf.ocrStatusOf(widget.page) == PdfOcrStatus.running;

  @override
  void initState() {
    super.initState();
    _pdf.addListener(_onChanged);
    _progress.addListener(_onProgress);
    _timer = Timer.periodic(widget.tick, (_) => _step());
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
    _timer?.cancel();
    _pdf.removeListener(_onChanged);
    _progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (!_reading) _reset();
    setState(() {});
  }

  void _onProgress() {
    if (_progress.value == null) _reset();
  }

  void _reset() {
    _revealed.clear();
    _seen.clear();
    _head = 0;
  }

  static String _key(OcrLine line) => '${line.text.trim()}@${line.rect.top.round()}@${line.rect.left.round()}';

  static bool _samePlace(Rect a, Rect b) {
    final overlap = a.intersect(b);
    if (overlap.width <= 0 || overlap.height <= 0) return false;
    final smaller = a.width * a.height < b.width * b.height ? a.width * a.height : b.width * b.height;
    return smaller > 0 && overlap.width * overlap.height / smaller > 0.5;
  }

  /// One hop of the head: to the next unread line, top first, or a step down the page when there is none.
  void _step() {
    if (!mounted || !_reading) return;
    final progress = _progress.value;
    if (progress == null) {
      _head = (_head + 0.06) % 1.0;
      setState(() {});
      return;
    }
    final pending = [
      for (final line in progress.lines)
        if (!_seen.contains(_key(line)) && line.text.trim().isNotEmpty) line,
    ]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    if (pending.isNotEmpty) {
      final take = (pending.length / OcrScanOverlay.backlogHops).ceil().clamp(1, pending.length);
      OcrLine? last;
      for (final line in pending.take(take)) {
        _seen.add(_key(line));
        final same = _revealed.indexWhere((r) => _samePlace(r.rect, line.rect));
        if (same >= 0) {
          _revealed[same] = line;
        } else {
          _revealed.add(line);
        }
        last = line;
      }
      final height = progress.imageSize.height;
      _head = height <= 0 ? 0 : (last!.rect.center.dy / height).clamp(0.0, 1.0);
    } else {
      _head = (_head + 0.06) % 1.0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 240),
      child: !_reading
          ? const SizedBox.shrink(key: ValueKey('idle'))
          : _Scan(
              key: const ValueKey('reading'),
              progress: _progress.value,
              revealed: List.of(_revealed),
              head: _head,
              animate: !reducedMotion,
              hop: widget.tick,
            ),
    );
  }
}

/// What is drawn on the page: the head with its scan-lines and tint, and the lines read so far.
class _Scan extends StatelessWidget {
  const _Scan({super.key, required this.progress, required this.revealed, required this.head, required this.animate, required this.hop});

  final OcrProgress? progress;
  final List<OcrLine> revealed;
  final double head;
  final bool animate;
  final Duration hop;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    if (!animate) {
      return Stack(
        key: const Key('ocr-scan-page'),
        fit: StackFit.expand,
        children: [
          ColoredBox(key: const Key('ocr-scan-still'), color: color.withValues(alpha: 0.06)),
          ..._boxes(),
        ],
      );
    }
    return Stack(
      key: const Key('ocr-scan-page'),
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: head.clamp(0.0, 1.0)),
          duration: hop,
          curve: Curves.easeInOut,
          builder: (context, value, _) => CustomPaint(
            key: const Key('ocr-scan-head'),
            painter: ScanPainter(value, color: color),
          ),
        ),
        ..._boxes(),
      ],
    );
  }

  List<Widget> _boxes() {
    final size = progress?.imageSize;
    if (size == null || size.isEmpty) return const [];
    return [
      for (final line in revealed)
        _LineBox(
          key: ValueKey('box@${line.rect.top.round()}@${line.rect.left.round()}'),
          line: line,
          size: size,
          animate: animate,
        ),
    ];
  }
}

/// A line that has been read, lit on the page where it is.
class _LineBox extends StatelessWidget {
  const _LineBox({super.key, required this.line, required this.size, required this.animate});

  final OcrLine line;
  final Size size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = line.rect;
    final widthFactor = (r.width / size.width).clamp(0.02, 1.0);
    final heightFactor = (r.height / size.height).clamp(0.006, 1.0);
    // Alignment places the child's edges proportionally (-1 puts its left edge on the parent's left edge, 1 its
    // right edge on the parent's right edge), so the alignment comes from where the box starts, not its centre.
    double along(double start, double extent) => extent >= 1 ? 0 : (2 * start / (1 - extent) - 1).clamp(-1.0, 1.0);
    final core = DecoratedBox(
      key: const Key('ocr-line-box'),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.2),
        border: Border.all(color: scheme.primary, width: 1.2),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 6)],
      ),
    );
    // A line flashes in as it is read, then settles. The animation is on the box alone, never on the
    // page-sized layer that places it: scaling that would move every box away from its line.
    final lit = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.scale(scale: 1.04 - 0.04 * t, child: child),
            ),
            child: core,
          )
        : core;
    return Align(
      alignment: Alignment(along(r.left / size.width, widthFactor), along(r.top / size.height, heightFactor)),
      child: FractionallySizedBox(widthFactor: widthFactor, heightFactor: heightFactor, child: lit),
    );
  }
}

/// Paints the scan head: a glowing line with fine scan-lines behind it, the row it is on lit, and what it has
/// passed tinted. [fraction] is how far down the page it is, 0 at the top and 1 at the bottom.
class ScanPainter extends CustomPainter {
  ScanPainter(this.fraction, {required this.color});

  final double fraction;
  final Color color;

  /// The rows the lit band is a share of: its height is one of this many rows of the page.
  static const rows = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final rowHeight = size.height / rows;
    final y = fraction.clamp(0.0, 1.0) * size.height;

    // What the scan has passed is tinted.
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, y), Paint()..color = color.withValues(alpha: 0.05));

    // Fine scan-lines behind the head, fading with distance.
    final trail = (size.height * 0.2).clamp(50.0, 170.0);
    final line = Paint()..strokeWidth = 1;
    for (var dy = 3.0; dy < trail; dy += 4) {
      final lineY = y - dy;
      if (lineY < 0) break;
      line.color = color.withValues(alpha: 0.24 * (1 - dy / trail));
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
            colors: [color.withValues(alpha: 0.02), color.withValues(alpha: 0.22)],
          ).createShader(row),
      );
    }

    // The head: a glow, then the line itself.
    canvas.drawRect(
      Rect.fromLTWH(0, y - 3, size.width, 6),
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), Paint()..color = color);
  }

  @override
  bool shouldRepaint(ScanPainter old) => old.fraction != fraction || old.color != color;
}
