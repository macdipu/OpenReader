import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:universal_document_viewer/ocr.dart';
import 'package:universal_document_viewer/pdf.dart';

import '../mlkit_text_recognizer.dart' show OcrProgress;
import '../ocr_recognizers.dart';

/// The scan that takes over the reader while OCR reads the page in view (CR-READER-SELECT-OCR SO-13).
///
/// With a recognizer that reports its progress (ML Kit), it is a full-screen stage ([OcrScanStage]): the
/// page large, a scan head hopping from one line of text to the next, each line lit exactly where it is
/// on the page as it is read, and a panel with the count and the latest lines. Otherwise it is a beam
/// stepping down the document row by row. It shows only while the page in view is being read, and goes
/// when the text is ready. With "remove animations" on nothing moves.
class OcrScanOverlay extends StatefulWidget {
  const OcrScanOverlay({super.key, required this.controller, this.progress, this.tick = const Duration(milliseconds: 140)});

  /// The open PDF; its current page decides when the scan shows.
  final PdfController controller;

  /// What the reading has found so far; the platform engine's when null.
  final ValueListenable<OcrProgress?>? progress;

  /// How long the scan head rests on a line before the next one.
  final Duration tick;

  /// How many rows the beam reads a page in, top to bottom, per sweep.
  static const rows = 28;

  /// How long the beam takes over one row (the hop and the rest).
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
  ValueListenable<OcrProgress?> get _progress => widget.progress ?? OcrRecognizers.progress;
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
    final show = _reading;
    if (!show) {
      if (_sweep.isAnimating) _sweep.stop();
    }
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240),
      child: show
          ? ValueListenableBuilder<OcrProgress?>(
              key: const ValueKey('reading'),
              valueListenable: _progress,
              builder: (context, progress, _) => Stack(
                fit: StackFit.expand,
                children: [
                  // No page image to show (an engine that reads in one go): the beam over the document.
                  if (progress?.image == null) _beam(context),
                  OcrScanStage(progress: _progress, tick: widget.tick),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('idle')),
    );
  }

  Widget _beam(BuildContext context) {
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
            painter: ScanPainter.sweep(_sweep.value, color: color),
          ),
        ),
      ),
    );
  }
}

/// The full-screen scan of a page: the page image large, the scan head hopping from line to line, the lines
/// lit where they are on the page as they are read, and a panel with the count and the latest lines.
///
/// The recognizer reports what it has found after each script; this plays those findings back one line
/// every [tick], top to bottom, so the reading is seen line by line. While nothing new is waiting, the
/// head keeps stepping down the page. Nothing shows until a reading reports.
class OcrScanStage extends StatefulWidget {
  const OcrScanStage({super.key, required this.progress, this.tick = const Duration(milliseconds: 140)});

  final ValueListenable<OcrProgress?> progress;

  /// How long the head rests on a line before the next one.
  final Duration tick;

  @override
  State<OcrScanStage> createState() => _OcrScanStageState();
}

class _OcrScanStageState extends State<OcrScanStage> {
  /// The lines the head has read, in the order it reached them. A later, better reading of the same
  /// place replaces the earlier one.
  final _revealed = <OcrLine>[];
  final _seen = <String>{};

  /// Where the head is, 0 (top) to 1 (bottom) of the page.
  double _head = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    _timer = Timer.periodic(widget.tick, (_) => _step());
  }

  @override
  void didUpdateWidget(OcrScanStage old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      old.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
      _reset();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _reset() {
    _revealed.clear();
    _seen.clear();
    _head = 0;
  }

  void _onProgress() {
    if (widget.progress.value == null && (_revealed.isNotEmpty || _head != 0)) {
      _reset();
      if (mounted) setState(() {});
    }
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
    final progress = widget.progress.value;
    if (progress == null || !mounted) return;
    final pending = [
      for (final line in progress.lines)
        if (!_seen.contains(_key(line))) line,
    ]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    if (pending.isNotEmpty) {
      final line = pending.first;
      _seen.add(_key(line));
      final same = _revealed.indexWhere((r) => _samePlace(r.rect, line.rect));
      if (same >= 0) {
        _revealed[same] = line;
      } else {
        _revealed.add(line);
      }
      final height = progress.imageSize.height;
      _head = height <= 0 ? 0 : (line.rect.center.dy / height).clamp(0.0, 1.0);
    } else {
      _head = (_head + 0.08) % 1.0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OcrProgress?>(
      valueListenable: widget.progress,
      builder: (context, progress, _) {
        if (progress == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final animate = !MediaQuery.disableAnimationsOf(context);
        final hasPage = progress.image != null && !progress.imageSize.isEmpty;
        return Stack(
          key: const Key('ocr-scan-stage'),
          fit: StackFit.expand,
          children: [
            if (hasPage) ...[
              // The page takes over the reader, so it cannot be scrolled while it is being read.
              AbsorbPointer(child: ColoredBox(color: scheme.surface.withValues(alpha: 0.95))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 84, 18, 188),
                child: Center(
                  child: _Page(progress: progress, revealed: List.of(_revealed), head: _head, animate: animate, hop: widget.tick),
                ),
              ),
            ],
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                child: _FindingsPanel(progress: progress, revealed: _revealed),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The page, with the scan head on the line being read and every line read so far lit where it is.
class _Page extends StatelessWidget {
  const _Page({required this.progress, required this.revealed, required this.head, required this.animate, required this.hop});

  final OcrProgress progress;
  final List<OcrLine> revealed;
  final double head;
  final bool animate;
  final Duration hop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = progress.imageSize;
    return AspectRatio(
      key: const Key('ocr-scan-preview'),
      aspectRatio: size.width / size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                progress.image!,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => ColoredBox(color: scheme.surface),
              ),
              // A little dimmer than the page itself, so the lit lines stand out.
              Container(color: scheme.surface.withValues(alpha: 0.28)),
              // The head, its scan-lines and what it has passed.
              TweenAnimationBuilder<double>(
                tween: Tween(end: head.clamp(0.0, 1.0)),
                duration: animate ? hop : Duration.zero,
                curve: Curves.easeInOut,
                builder: (context, value, _) => CustomPaint(
                  key: const Key('ocr-scan-head'),
                  painter: ScanPainter.at(value, color: scheme.primary),
                ),
              ),
              for (final line in revealed)
                _LineBox(key: ValueKey('box@${line.rect.top.round()}@${line.rect.left.round()}'), line: line, size: size, animate: animate),
            ],
          ),
        ),
      ),
    );
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
    final cx = ((r.center.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final cy = ((r.center.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    final box = Align(
      alignment: Alignment(cx, cy),
      child: FractionallySizedBox(
        widthFactor: (r.width / size.width).clamp(0.02, 1.0),
        heightFactor: (r.height / size.height).clamp(0.008, 1.0),
        child: DecoratedBox(
          key: const Key('ocr-line-box'),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.2),
            border: Border.all(color: scheme.primary, width: 1.2),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 6)],
          ),
        ),
      ),
    );
    if (!animate) return box;
    // A line flashes in as it is read, then settles.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 1.04 - 0.04 * t, child: child),
      ),
      child: box,
    );
  }
}

/// The bar for the scripts read so far, how many lines the head has read, and the latest few.
class _FindingsPanel extends StatelessWidget {
  const _FindingsPanel({required this.progress, required this.revealed});

  final OcrProgress progress;
  final List<OcrLine> revealed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = revealed.length;
    final latest = count <= 3 ? revealed : revealed.sublist(count - 3);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        elevation: 4,
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress.fraction == 0 ? null : progress.fraction, minHeight: 3),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                label: count == 1 ? '1 line found so far' : '$count lines found so far',
                excludeSemantics: true,
                child: Text(
                  count == 0 ? 'Scanning…' : (count == 1 ? '1 line found' : '$count lines found'),
                  style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
              ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in latest)
                      _FadeIn(
                        key: ValueKey('${line.text}@${line.rect.top.round()}'),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            line.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child in once, the first time it is built.
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset((1 - t) * -8, 0), child: child),
      ),
      child: child,
    );
  }
}

/// Paints the scan head: a glowing line with fine scan-lines behind it, the row it is on lit, and what it has
/// passed tinted. Either at a fraction of the height ([ScanPainter.at]) or following the stepped sweep of the
/// beam ([ScanPainter.sweep]).
class ScanPainter extends CustomPainter {
  /// The head [fraction] (0 top, 1 bottom) of the way down.
  ScanPainter.at(double fraction, {required this.color}) : _fraction = fraction, _sweep = null;

  /// The head at [sweep] (0 to 1) of the stepped sweep: it hops to the bottom of each row, then rests.
  ScanPainter.sweep(double sweep, {required this.color}) : _fraction = null, _sweep = sweep;

  final double? _fraction;
  final double? _sweep;
  final Color color;

  /// How much of each row's time the head spends hopping; the rest it rests.
  static const _hopShare = 0.38;

  /// Where the head is, in pixels from the top, on the stepped sweep.
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
    final y = _fraction != null ? _fraction.clamp(0.0, 1.0) * size.height : headY(_sweep!, size.height);

    // What the scan has passed is tinted.
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, y), Paint()..color = color.withValues(alpha: 0.05));

    // Fine scan-lines behind the head, fading with distance.
    final trail = (size.height * 0.2).clamp(60.0, 170.0);
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
  bool shouldRepaint(ScanPainter old) => old._fraction != _fraction || old._sweep != _sweep || old.color != color;
}
