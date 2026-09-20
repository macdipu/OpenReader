import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'pdf_reader_controller.dart';

/// BRD §9.10 PDF Reader Screen (DESIGN_SPEC.md #09 / #14 - light + AMOLED).
class PdfReaderView extends GetView<PdfReaderController> {
  const PdfReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReaderAppBar(controller: controller),
      body: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        return Stack(
          children: [
            Obx(() => _buildViewer(context)),
            Obx(() => controller.showThumbnails.value
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 84),
                      child: _ThumbnailStrip(controller: controller),
                    ),
                  )
                : const SizedBox.shrink()),
            Align(
              alignment: Alignment.bottomCenter,
              child: _FloatingToolbar(controller: controller),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildViewer(BuildContext context) {
    final searcher = controller.textSearcher.value;
    return PdfViewer.file(
      controller.document.path,
      controller: controller.pdfController,
      initialPageNumber: controller.initialPageNumber,
      passwordProvider: controller.providePassword,
      params: PdfViewerParams(
        backgroundColor: context.background,
        onViewerReady: controller.onViewerReady,
        onPageChanged: controller.onPageChanged,
        pagePaintCallbacks: searcher == null ? null : [searcher.pageTextMatchPaintCallback],
        layoutPages: controller.viewMode.value == PdfReaderViewMode.horizontal ? _horizontalLayout : null,
        errorBannerBuilder: (context, error, stackTrace, documentRef) => _ReaderErrorView(controller: controller, error: error),
      ),
    );
  }

  static PdfPageLayout _horizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold(0.0, (prev, page) => max(prev, page.height)) + params.margin * 2;
    final pageLayouts = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      pageLayouts.add(Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height));
      x += page.width + params.margin;
    }
    return PdfPageLayout(pageLayouts: pageLayouts, documentSize: Size(x, height));
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PdfReaderController controller;

  const _ReaderAppBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40);

  @override
  Widget build(BuildContext context) {
    final accent = DocumentCategory.pdf.accentColor(context);
    final tint = DocumentCategory.pdf.tintColor(context);

    return AppBar(
      title: Obx(
        () => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: context.titleMedium,
                decoration: InputDecoration(
                  hintText: 'Search in document',
                  border: InputBorder.none,
                  hintStyle: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
                ),
                onChanged: controller.onSearchQueryChanged,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text('PDF', style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800, fontSize: 8)),
                  ),
                  Flexible(
                    child: Text(
                      controller.document.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.titleMedium,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        Obx(
          () => controller.isSearching.value
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: controller.stopSearching)
              : IconButton(
                  icon: const Icon(Icons.search_rounded),
                  // Text search needs a live document (see textSearcher's doc
                  // comment); disabled until onViewerReady supplies one.
                  onPressed: controller.textSearcher.value != null ? controller.startSearching : null,
                ),
        ),
        Obx(
          () => IconButton(
            icon: Icon(
              controller.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: controller.isFavorite ? context.secondary : null,
            ),
            onPressed: controller.toggleFavorite,
          ),
        ),
        PopupMenuButton<_ReaderAction>(
          onSelected: (action) => _handle(action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
          ],
        ),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller)),
    );
  }

  void _handle(_ReaderAction action) {
    switch (action) {
      case _ReaderAction.share:
        controller.share();
      case _ReaderAction.openWith:
        controller.openWith();
    }
  }
}

enum _ReaderAction { share, openWith }

class _SearchStatusBar extends StatelessWidget {
  final PdfReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSearching.value) return const SizedBox.shrink();
      final searcher = controller.textSearcher.value;
      if (searcher == null) return const SizedBox.shrink();
      return Container(
        color: context.surfaceContainerLow,
        child: ListenableBuilder(
          listenable: searcher,
          builder: (context, _) {
            final String label;
            if (searcher.pattern == null) {
              label = '';
            } else if (searcher.isSearching) {
              label = 'Searching…';
            } else if (searcher.matches.isEmpty) {
              // BRD §13.
              label = 'No searchable text found.';
            } else {
              label = '${(searcher.currentIndex ?? 0) + 1} of ${searcher.matches.length} result(s)';
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant))),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    color: context.onSurfaceVariant,
                    onPressed: searcher.hasMatches ? controller.goToPrevMatch : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: context.onSurfaceVariant,
                    onPressed: searcher.hasMatches ? controller.goToNextMatch : null,
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}

/// Floating capsule bottom toolbar - DESIGN_SPEC.md "Floating reader
/// toolbar / HUD pill": page scrub + view controls in one pill, hovering
/// above the page rather than docked full-width.
class _FloatingToolbar extends StatelessWidget {
  final PdfReaderController controller;

  const _FloatingToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.pageCount.value < 1) return const SizedBox.shrink();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: context.surfaceContainerLowest.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.outlineVariant),
            boxShadow: isDark
                ? null
                : [BoxShadow(color: context.shadow.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.grid_view_rounded, color: context.onSurfaceVariant, size: 20),
                onPressed: controller.toggleThumbnails,
              ),
              TextButton(
                onPressed: () => _showJumpToPageDialog(context),
                child: Text(
                  'Page ${controller.currentPage.value} of ${controller.pageCount.value}',
                  style: context.labelMedium?.copyWith(color: context.onSurface),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  controller.viewMode.value == PdfReaderViewMode.horizontal
                      ? Icons.view_column_rounded
                      : Icons.view_agenda_outlined,
                  color: context.secondary,
                  size: 20,
                ),
                onPressed: controller.toggleViewMode,
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _showJumpToPageDialog(BuildContext context) async {
    final controllerText = TextEditingController(text: controller.currentPage.value.toString());
    final page = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to page'),
        content: TextField(
          controller: controllerText,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1–${controller.pageCount.value}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controllerText.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (page != null) unawaited(controller.jumpToPage(page));
  }
}

class _ThumbnailStrip extends StatelessWidget {
  final PdfReaderController controller;

  const _ThumbnailStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: PdfDocumentViewBuilder(
        documentRef: controller.pdfController.documentRef,
        builder: (context, document) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          itemCount: document?.pages.length ?? 0,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => controller.jumpToPage(pageNumber),
                child: Obx(
                  () => Container(
                    width: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: controller.currentPage.value == pageNumber ? context.secondary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(child: PdfPageView(document: document, pageNumber: pageNumber, maximumDpi: 50)),
                        Text('$pageNumber', style: context.labelSmall?.copyWith(color: context.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReaderErrorView extends StatelessWidget {
  final PdfReaderController controller;
  final Object error;

  const _ReaderErrorView({required this.controller, required this.error});

  @override
  Widget build(BuildContext context) {
    // BRD §13: password failures are handled entirely by the password
    // dialog retry loop (PdfReaderController.providePassword); reaching
    // here with a PdfPasswordException means the user already cancelled and
    // left, so this always shows the generic corrupted/unsupported message.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: context.error),
            const SizedBox(height: 16),
            Text(
              'This document may be damaged or incomplete.',
              textAlign: TextAlign.center,
              style: context.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => Get.back(), child: const Text('Close')),
                const SizedBox(width: 8),
                FilledButton(onPressed: controller.openWith, child: const Text('Try another app')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
