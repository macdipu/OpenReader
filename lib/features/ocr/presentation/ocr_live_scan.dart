import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:universal_document_viewer/ocr.dart';

import '../mlkit_text_recognizer.dart' show OcrProgress;

/// The reading of a page as it happens (CR-READER-SELECT-OCR SO-13): a small preview of the page with a
/// scan head that hops from one line of text to the next, lighting each line up where it really is on
/// the page as it is read, while its text streams in beside it with a count and a bar for the scripts
/// read so far.
///
/// The recognizer reports what it has found after each script; this plays those findings back one line
/// every [tick], top to bottom, so the reading is seen line by line. While nothing new is waiting, the
/// head keeps stepping down the page.
class OcrLiveScan extends StatefulWidget {
  const OcrLiveScan({super.key, required this.progress, this.tick = const Duration(milliseconds: 140)});

  final ValueListenable<OcrProgress?> progress;

  /// How long the head rests on a line before the next one.
  final Duration tick;

  @override
  State<OcrLiveScan> createState() => _OcrLiveScanState();
}

class _OcrLiveScanState extends State<OcrLiveScan> {
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
  void didUpdateWidget(OcrLiveScan old) {
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
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        final preview = progress.image == null || progress.imageSize.isEmpty
            ? null
            : _PagePreview(
                key: const Key('ocr-scan-preview'),
                progress: progress,
                revealed: List.of(_revealed),
                head: _head,
                animate: !reducedMotion,
                hop: widget.tick,
              );
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview != null) ...[preview, const SizedBox(width: 14)],
              Expanded(child: _Findings(progress: progress, revealed: _revealed)),
            ],
          ),
        );
      },
    );
  }
}

/// The page, dimmed, with the lines read so far lit where they are and the scan head on the line being read.
class _PagePreview extends StatelessWidget {
  const _PagePreview({
    super.key,
    required this.progress,
    required this.revealed,
    required this.head,
    required this.animate,
    required this.hop,
  });

  final OcrProgress progress;
  final List<OcrLine> revealed;
  final double head;
  final bool animate;
  final Duration hop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = progress.imageSize;
    final duration = animate ? hop : Duration.zero;
    return SizedBox(
      height: 150,
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  progress.image!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(color: scheme.surface),
                ),
                // Everything the head has passed this round is a little darker, so the scan leaves a mark.
                Container(color: scheme.surface.withValues(alpha: 0.35)),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: head),
                  duration: duration,
                  curve: Curves.easeInOut,
                  builder: (context, value, _) => Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: value.clamp(0.0, 1.0),
                      widthFactor: 1,
                      child: ColoredBox(color: scheme.primary.withValues(alpha: 0.08)),
                    ),
                  ),
                ),
                for (final line in revealed) _LineBox(key: ValueKey(_boxKey(line)), line: line, size: size, animate: animate),
                // The head: a bright line with a glow, hopping from line to line.
                AnimatedAlign(
                  alignment: Alignment(0, head.clamp(0.0, 1.0) * 2 - 1),
                  duration: duration,
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 1)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _boxKey(OcrLine line) => 'box@${line.rect.top.round()}@${line.rect.left.round()}';
}

/// A line that has been read, lit on the preview where it is on the page.
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
        heightFactor: (r.height / size.height).clamp(0.01, 1.0),
        child: DecoratedBox(
          key: const Key('ocr-line-box'),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.28),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.9), width: 0.8),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
    if (!animate) return box;
    // A line flashes bright as it is read, then settles.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: box,
    );
  }
}

/// The bar for the scripts read so far, how many lines the head has read, and the latest few.
class _Findings extends StatelessWidget {
  const _Findings({required this.progress, required this.revealed});

  final OcrProgress progress;
  final List<OcrLine> revealed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = revealed.length;
    final latest = count <= 4 ? revealed : revealed.sublist(count - 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: progress.fraction == 0 ? null : progress.fraction, minHeight: 3),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: count == 1 ? '1 line found so far' : '$count lines found so far',
          excludeSemantics: true,
          child: Text(
            count == 0 ? 'Scanning…' : (count == 1 ? '1 line found' : '$count lines found'),
            style: text.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
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
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      line.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
