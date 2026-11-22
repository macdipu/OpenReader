import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:universal_document_viewer/ocr.dart';
import 'package:universal_document_viewer/pdf.dart';

import '../ocr_progress.dart';
import '../ocr_recognizers.dart';

/// The scan over the page in view while OCR reads it (CR-READER-SELECT-OCR SO-13), drawn on the document
/// itself: a beam that steps down the page row by row, in quick hops with a short rest on each, leaving fine
/// scan-lines behind it and a tint over what it has passed; and the text found, popping up as tags beside the
/// beam, one line at a time as it is read. It lets touches through, so the page can still be scrolled and
/// zoomed, and shows only while the page in view is being read. With "remove animations" on, the beam is a
/// still tint and the tags simply appear.
///
/// The tags follow the beam, not the text itself: the viewer does not say where a page is drawn.
class OcrScanOverlay extends StatefulWidget {
  const OcrScanOverlay({
    super.key,
    required this.controller,
    this.progress,
    this.tick = const Duration(milliseconds: 140),
  });

  /// The open PDF; its current page decides when the scan shows.
  final PdfController controller;

  /// What the reading has found so far; the platform engine's when null.
  final ValueListenable<OcrProgress?>? progress;

  /// How often the next line found is shown.
  final Duration tick;

  /// How many rows the beam reads a page in, top to bottom, per sweep.
  static const rows = 28;

  /// How long the beam takes over one row (the hop and the rest).
  static const rowTime = Duration(milliseconds: 110);

  /// How long a tag stays up, and how much of that it takes to fade out.
  static const tagLife = Duration(milliseconds: 1700);
  static const _tagFade = Duration(milliseconds: 350);

  /// The most tags up at once.
  static const maxTags = 5;

  @override
  State<OcrScanOverlay> createState() => _OcrScanOverlayState();
}

class _Tag {
  _Tag(this.text, this.fraction, this.born);

  final String text;

  /// Where down the page the beam was when the line was read, 0 to 1.
  final double fraction;

  /// The tick it was read on.
  final int born;
}

class _OcrScanOverlayState extends State<OcrScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: OcrScanOverlay.rowTime * OcrScanOverlay.rows,
  );
  final _tags = <_Tag>[];
  var _ticks = 0;
  final _seen = <String>{};
  Timer? _timer;
  var _height = 0.0;

  PdfController get _pdf => widget.controller;
  ValueListenable<OcrProgress?> get _progress => widget.progress ?? OcrRecognizers.progress;
  bool get _reading =>
      _pdf.canRecognize && _pdf.pageCount > 0 && _pdf.ocrStatusOf(_pdf.currentPage - 1) == PdfOcrStatus.running;

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
    _sweep.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onProgress() {
    if (_progress.value == null) {
      _tags.clear();
      _seen.clear();
    }
  }

  static String _key(OcrLine line) => '${line.text.trim()}@${line.rect.top.round()}@${line.rect.left.round()}';

  /// Shows the next lines found, top of the page first, and takes down the tags that have had their time.
  void _step() {
    if (!mounted) return;
    var changed = false;
    // Time is counted in ticks, not by a clock, so it runs on the same time as the timer that drives it.
    final now = ++_ticks;
    final life = (OcrScanOverlay.tagLife.inMilliseconds / widget.tick.inMilliseconds).ceil();
    final before = _tags.length;
    _tags.removeWhere((tag) => now - tag.born > life);
    if (_tags.length != before) changed = true;

    final progress = _reading ? _progress.value : null;
    if (progress != null) {
      final pending = [
        for (final line in progress.lines)
          if (!_seen.contains(_key(line)) && line.text.trim().isNotEmpty) line,
      ]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
      if (pending.isNotEmpty) {
        // One line per step; a long backlog is taken several at a time so a full page is read in seconds.
        final take = (pending.length / 8).ceil().clamp(1, pending.length);
        for (final line in pending.take(take)) {
          _seen.add(_key(line));
          _tags.add(_Tag(line.text.trim(), _beamFraction(context), now));
        }
        while (_tags.length > OcrScanOverlay.maxTags) {
          _tags.removeAt(0);
        }
        changed = true;
      }
    } else if (_tags.isNotEmpty && !_reading) {
      _tags.clear();
      changed = true;
    }
    if (changed) setState(() {});
  }

  /// Where the beam is now, as a fraction of the page's height (the middle while it holds still).
  double _beamFraction(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || _height <= 0) return 0.4;
    return (ScanPainter.headY(_sweep.value, _height) / _height).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final show = _reading;
    if (!show && _sweep.isAnimating) _sweep.stop();
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240),
      child: show
          ? IgnorePointer(
              key: const ValueKey('reading'),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _height = constraints.maxHeight;
                  return Stack(
                    fit: StackFit.expand,
                    children: [_beam(context), ..._tagWidgets(context, constraints.maxHeight)],
                  );
                },
              ),
            )
          : const SizedBox.shrink(key: ValueKey('idle')),
    );
  }

  Widget _beam(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_sweep.isAnimating) _sweep.stop();
      return ColoredBox(key: const Key('ocr-scan-still'), color: color.withValues(alpha: 0.06));
    }
    if (!_sweep.isAnimating) _sweep.repeat();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) => CustomPaint(
          key: const Key('ocr-scan-beam'),
          size: Size.infinite,
          painter: ScanPainter(_sweep.value, color: color),
        ),
      ),
    );
  }

  List<Widget> _tagWidgets(BuildContext context, double height) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final life = (OcrScanOverlay.tagLife.inMilliseconds / widget.tick.inMilliseconds).ceil();
    final fade = (OcrScanOverlay._tagFade.inMilliseconds / widget.tick.inMilliseconds).ceil();
    final widgets = <Widget>[];
    var floor = 0.0;
    for (final tag in _tags) {
      final age = _ticks - tag.born;
      final fadingOut = age > life - fade;
      // Where the beam was, kept clear of the tag above it.
      final top = (tag.fraction * height - 14).clamp(floor, (height - 34).clamp(floor, double.infinity));
      floor = top + 30;
      widgets.add(
        Positioned(
          key: ValueKey('tag@${tag.born}@${tag.text}'),
          left: 14,
          top: top,
          child: _TagChip(text: tag.text, visible: !fadingOut, animate: animate),
        ),
      );
    }
    return widgets;
  }
}

/// One line that has been read, as a small tag.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, required this.visible, required this.animate});

  final String text;
  final bool visible;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Container(
      key: const Key('ocr-found-tag'),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.62),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.8)),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
      ),
    );
    if (!animate) return visible ? chip : const SizedBox.shrink();
    // Pops in from the left as the beam reads the line, and fades out when its time is up.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? t.clamp(0.0, 1.0) : 0,
        child: Transform.translate(offset: Offset((1 - t) * -24, 0), child: child),
      ),
      child: chip,
    );
  }
}

/// Paints the scan head: a glowing line with fine scan-lines behind it, the row it is on lit, and what it has
/// passed tinted. [sweep] (0 at the top of the page, 1 at the bottom) is where it is on the stepped sweep: it
/// hops to the bottom of each row, then rests.
class ScanPainter extends CustomPainter {
  ScanPainter(this.sweep, {required this.color});

  final double sweep;
  final Color color;

  /// How much of each row's time the head spends hopping; the rest it rests.
  static const _hopShare = 0.38;

  /// Where the head is, in pixels from the top.
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

    // What the scan has passed is tinted.
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, y), Paint()..color = color.withValues(alpha: 0.045));

    // Fine scan-lines behind the head, fading with distance.
    const trail = 150.0;
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
  bool shouldRepaint(ScanPainter old) => old.sweep != sweep || old.color != color;
}
