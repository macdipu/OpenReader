import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_document_viewer/pdf.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/reader/reader_night_mode_view.dart';
import '../../../core/presentation/widgets/reader/reader_toolbar.dart';
import 'pdf_reader_controller.dart';
import '../../../core/presentation/widgets/app_shortcuts.dart';

/// BRD §9.10 PDF Reader Screen (DESIGN_SPEC.md #09 / #14 - light + AMOLED).
class PdfReaderView extends GetView<PdfReaderController> {
  const PdfReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold reads appBar.preferredSize only when it builds, so it is rebuilt
    // on search toggle to let the bar collapse back to toolbar height.
    return AppShortcuts(
      // Ctrl/Cmd+F searches; Esc closes search, then the reader (UX-34).
      onSearch: controller.searchFromShortcut,
      onEscape: controller.escape,
      child: Obx(() => ReaderNightModeView(
      // The whole reader, bars included, goes dark at night.
      enabled: controller.nightMode.value,
      // A context under the night theme for the whole screen; its own Obx,
      // since the builder runs after the outer one has finished.
      child: Builder(builder: (context) => Obx(() => Scaffold(
      appBar: controller.isFullscreen.value
          ? null
          : _ReaderAppBar(controller: controller, searching: controller.isSearching.value),
      body: ReaderFullscreenScope(
        controller: controller,
        child: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        return Stack(
          children: [
            // Night mode inverts the pages and thumbnails (UX-33).
            Obx(() => ReaderNightModeView(
                  enabled: controller.nightMode.value,
                  paper: true,
                  child: Stack(
                    children: [
                      // Clearance below the last page for the toolbar (and the
                      // strip when open), in screen pixels so it holds at any zoom.
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: controller.isFullscreen.value
                              ? 0
                              : 76 + MediaQuery.paddingOf(context).bottom + (controller.showThumbnails.value ? 128 : 0),
                        ),
                        // Under the night-mode filter's theme, for the backdrop.
                        child: Builder(builder: _buildViewer),
                      ),
                      if (controller.showThumbnails.value && !controller.isFullscreen.value)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 84 + MediaQuery.paddingOf(context).bottom),
                            child: _ThumbnailStrip(controller: controller),
                          ),
                        ),
                    ],
                  ),
                )),
            Obx(() => controller.isFullscreen.value
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.bottomCenter,
                    // Clear of the system navigation bar when drawn
                    // edge to edge (as after full screen).
                    child: SafeArea(top: false, child: _FloatingToolbar(controller: controller)),
                  )),
          ],
        );
      }),
      ),
    ))))),
    );
  }

  Widget _buildViewer(BuildContext context) {
    return PdfView(
      controller: controller.pdf,
      backgroundColor: context.background,
      // In fullscreen, a tap on the page brings the controls back.
      onTap: () {
        if (!controller.isFullscreen.value) return false;
        controller.toggleFullscreen();
        return true;
      },
      errorBuilder: (context, error) => _ReaderErrorView(controller: controller, error: error),
    );
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PdfReaderController controller;

  /// Whether the search field (and its result bar below) is showing.
  final bool searching;

  const _ReaderAppBar({required this.controller, required this.searching});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (searching ? 40 : 0));

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
                // Enter steps to the next match; the field keeps focus to press again.
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => controller.goToNextMatch(),
                onEditingComplete: () {},
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
              ? IconButton(tooltip: 'Close search', icon: const Icon(Icons.close_rounded), onPressed: controller.stopSearching)
              : IconButton(
                tooltip: 'Search in document',
                  icon: const Icon(Icons.search_rounded),
                  // Search needs the open document.
                  onPressed: controller.isReady.value ? controller.startSearching : null,
                ),
        ),
        Obx(
          () => IconButton(
            tooltip: controller.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(
              controller.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: controller.isFavorite ? context.secondary : null,
            ),
            onPressed: controller.toggleFavorite,
          ),
        ),
        PopupMenuButton<_ReaderAction>(
          onSelected: (action) => _handle(action),
          tooltip: 'More actions',
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
          ],
        ),
      ],
      bottom: searching
          ? PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller))
          : null,
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
      return Container(
        color: context.surfaceContainerLow,
        child: ValueListenableBuilder(
          valueListenable: controller.pdf.searchState,
          builder: (context, search, _) {
            final label = DocumentViewerStrings.of(context).searchStatus(search);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant))),
                  IconButton(
                    tooltip: 'Previous match',
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    color: context.onSurfaceVariant,
                    onPressed: search.matchCount > 0 ? controller.goToPrevMatch : null,
                  ),
                  IconButton(
                    tooltip: 'Next match',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: context.onSurfaceVariant,
                    onPressed: search.matchCount > 0 ? controller.goToNextMatch : null,
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
      return Padding(
        // As ReaderBottomBar pads the other readers' toolbars.
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        child: ReaderToolbar(
          children: [
            ReaderPreviewsButton(
              tooltip: 'Page thumbnails',
              showing: controller.showThumbnails.value,
              onPressed: controller.toggleThumbnails,
            ),
            ReaderPositionButton(
              label: 'Page ${controller.currentPage.value} of ${controller.pageCount.value}',
              onPressed: () => _showJumpToPageDialog(context),
            ),
            ReaderZoomButtons(onZoomOut: controller.zoomOut, onZoomIn: controller.zoomIn),
            ReaderToolbarButton(icon: Icons.fit_screen_outlined, tooltip: 'Fit width', onPressed: controller.fitWidth),
            ReaderToolbarButton(
              icon: controller.viewMode.value == PdfViewMode.horizontal
                  ? Icons.view_column_rounded
                  : Icons.view_agenda_outlined,
              tooltip: controller.viewMode.value == PdfViewMode.horizontal ? 'Continuous scroll' : 'Page by page',
              onPressed: controller.toggleViewMode,
            ),
            ReaderNightModeButton(on: controller.nightMode.value, onPressed: controller.toggleNightMode),
            ReaderFullscreenButton(onPressed: controller.toggleFullscreen),
          ],
        ),
      );
    });
  }

  Future<void> _showJumpToPageDialog(BuildContext context) async {
    final page = await showGoToNumberDialog(
      context,
      title: 'Go to page',
      current: controller.currentPage.value,
      max: controller.pageCount.value,
    );
    if (page != null) unawaited(controller.jumpToPage(page));
  }
}

class _ThumbnailStrip extends StatefulWidget {
  final PdfReaderController controller;

  const _ThumbnailStrip({required this.controller});

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

/// Keeps the current page's thumbnail centred as pages change (UX-33).
class _ThumbnailStripState extends State<_ThumbnailStrip> {
  /// One thumbnail: 70 wide plus 4 padding each side.
  static const _itemExtent = 78.0;

  final _scrollController = ScrollController();
  Worker? _pageWorker;

  PdfReaderController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _pageWorker = ever(controller.currentPage, (_) => _centreCurrentPage(animate: true));
    WidgetsBinding.instance.addPostFrameCallback((_) => _centreCurrentPage(animate: false));
  }

  void _centreCurrentPage({required bool animate}) {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (8 + (controller.currentPage.value - 1) * _itemExtent + _itemExtent / 2 - position.viewportDimension / 2)
        .clamp(0.0, position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _pageWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
      child: Obx(
        () => ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          itemCount: controller.isReady.value ? controller.pageCount.value : 0,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Obx(() => Semantics(button: true, selected: controller.currentPage.value == pageNumber, label: 'Page $pageNumber', child: GestureDetector(
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
                        Expanded(child: PdfPageThumbnail(controller: controller.pdf, pageNumber: pageNumber)),
                        Text('$pageNumber', style: context.labelSmall?.copyWith(color: context.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ))),
            );
          },
        ),
      ),
    );
  }
}

class _ReaderErrorView extends StatelessWidget {
  final PdfReaderController controller;
  final DocumentLoadError error;

  const _ReaderErrorView({required this.controller, required this.error});

  @override
  Widget build(BuildContext context) {
    // BRD §13: password failures are handled entirely by the password
    // dialog retry loop (PdfReaderController.providePassword); reaching
    // here after a password error means the user already cancelled and
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
