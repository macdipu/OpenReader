import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:universal_document_viewer/pdf.dart';

import '../mlkit_text_recognizer.dart' show OcrProgress;
import '../ocr_recognizers.dart';

/// A strip over a PDF reader offering OCR for the page in view: shown for a
/// page that has no text of its own (a scan), while it is being read, and
/// when it failed. Nothing for a page with text, and nothing at all when the
/// device has no recognizer (CR-READER-SELECT-OCR SO-13).
class OcrPageBanner extends StatefulWidget {
  /// Watches [controller]'s current page.
  const OcrPageBanner({super.key, required this.controller, this.onNoText, this.progress});

  /// The open PDF.
  final PdfController controller;

  /// Called when a read finished and found no text on the page.
  final VoidCallback? onNoText;

  /// What the reading has found so far (the platform engine's, when null). It fills the card shown while reading.
  final ValueListenable<OcrProgress?>? progress;

  @override
  State<OcrPageBanner> createState() => _OcrPageBannerState();
}

class _OcrPageBannerState extends State<OcrPageBanner> {
  final _needs = <int, bool>{};
  int? _checking;

  PdfController get _pdf => widget.controller;
  int get _page => _pdf.currentPage - 1;

  @override
  void initState() {
    super.initState();
    _pdf.addListener(_onChanged);
    _check();
  }

  @override
  void didUpdateWidget(OcrPageBanner old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      _pdf.addListener(_onChanged);
      _needs.clear();
      _check();
    }
  }

  @override
  void dispose() {
    _pdf.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    _check();
    setState(() {});
  }

  Future<void> _check() async {
    final page = _page;
    if (!_pdf.canRecognize || _pdf.status != DocumentStatus.ready || _pdf.pageCount == 0) return;
    if (_needs.containsKey(page) || _checking == page) return;
    _checking = page;
    final needs = await _pdf.pageNeedsOcr(page);
    _checking = null;
    if (!mounted) return;
    setState(() => _needs[page] = needs);
  }

  Future<void> _extract() async {
    final page = _page;
    final found = await _pdf.recognizePage(page);
    if (!mounted) return;
    if (!found && _pdf.ocrStatusOf(page) == PdfOcrStatus.done) widget.onNoText?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_pdf.canRecognize || _pdf.pageCount == 0) return const SizedBox.shrink();
    final page = _page;
    final status = _pdf.ocrStatusOf(page);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final Widget? content = switch (status) {
      PdfOcrStatus.running => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 12),
              Flexible(child: Text('Reading the text on this page…', style: text.bodyMedium)),
              const SizedBox(width: 8),
              TextButton(onPressed: () => _pdf.cancelOcr(page), child: const Text('Cancel')),
            ],
          ),
          _LiveFindings(progress: widget.progress ?? OcrRecognizers.progress),
        ],
      ),
      PdfOcrStatus.failed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Flexible(child: Text('Could not read the text on this page', style: text.bodyMedium)),
          const SizedBox(width: 8),
          TextButton(onPressed: _extract, child: const Text('Try again')),
        ],
      ),
      PdfOcrStatus.done => null,
      _ when _needs[page] == true => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.document_scanner_outlined, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Flexible(child: Text('This page is a picture, so its text can’t be selected', style: text.bodyMedium)),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: _extract, child: const Text('Extract text')),
        ],
      ),
      _ => null,
    };
    if (content == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Material(
        elevation: 3,
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: content),
        ),
      ),
    );
  }
}

/// The findings of a reading as they come in: a bar for the scripts read so far, how many lines have been
/// found, and the latest few fading in. Nothing until the first script has reported.
class _LiveFindings extends StatefulWidget {
  const _LiveFindings({required this.progress});

  final ValueListenable<OcrProgress?> progress;

  @override
  State<_LiveFindings> createState() => _LiveFindingsState();
}

class _LiveFindingsState extends State<_LiveFindings> {
  /// Line texts in the order they were first found.
  final _found = <String>[];

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    _onProgress();
  }

  @override
  void didUpdateWidget(_LiveFindings old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      old.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
      _found.clear();
      _onProgress();
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    final progress = widget.progress.value;
    if (progress == null) {
      _found.clear();
      return;
    }
    final fresh = [for (final line in progress.lines) if (!_found.contains(line.text.trim())) line.text.trim()];
    if (fresh.isEmpty) return;
    _found.addAll(fresh);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OcrProgress?>(
      valueListenable: widget.progress,
      builder: (context, progress, _) {
        if (progress == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final count = progress.lines.length;
        final latest = _found.length <= 3 ? _found : _found.sublist(_found.length - 3);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
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
                        key: ValueKey(line),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            line,
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
          ),
        );
      },
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 6), child: child),
      ),
      child: child,
    );
  }
}
