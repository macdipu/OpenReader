import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:universal_document_viewer/pdf.dart';

import '../ocr_progress.dart';
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

  /// What the reading has found so far, for the line count (the platform engine's when null).
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
      PdfOcrStatus.running => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 12),
          Flexible(
            child: ValueListenableBuilder<OcrProgress?>(
              valueListenable: widget.progress ?? OcrRecognizers.progress,
              builder: (context, progress, _) {
                final found = progress?.lines.length ?? 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reading the text on this page…', style: text.bodyMedium),
                    if (found > 0)
                      Text(
                        found == 1 ? '1 line found' : '$found lines found',
                        style: text.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () => _pdf.cancelOcr(page), child: const Text('Cancel')),
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
