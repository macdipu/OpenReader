import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_document_viewer/word.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/reader/reader_preview_strip.dart';
import '../../../core/presentation/widgets/reader/reader_night_mode_view.dart';
import '../../../core/presentation/widgets/reader/reader_toolbar.dart';
import 'word_reader_controller.dart';
import '../../../core/presentation/widgets/app_shortcuts.dart';

/// BRD §9.11 Word Reader Screen (DESIGN_SPEC.md #02 / #13 - light + AMOLED).
class WordReaderView extends GetView<WordReaderController> {
  const WordReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold reads appBar.preferredSize only when it builds, so it is rebuilt
    // on search toggle to let the bar collapse back to toolbar height.
    return AppShortcuts(
      // Ctrl/Cmd+F searches; Esc closes search, then the reader (UX-34).
      onSearch: controller.startSearching,
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
      bottomNavigationBar: controller.isFullscreen.value || controller.status.value.isBusy || controller.hasError.value
          ? null
          : _WordToolbar(controller: controller),
      body: ReaderFullscreenScope(
        controller: controller,
        child: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.hasError.value) return _ReaderErrorView(controller: controller);
        return Container(
          color: context.background,
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            // Print layout is white paper, inverted at night; continuous
            // follows the screen's (night) theme.
            child: ReaderNightModeView(
              enabled: controller.nightMode.value && controller.isPaged.value,
              paper: true,
              child: WordView(controller: controller.word),
            ),
          ),
        );
      }),
      ),
    ))))),
    );
  }
}

/// Previews · page (print layout) or how far through (continuous) · zoom ·
/// layout · full screen.
class _WordToolbar extends StatelessWidget {
  final WordReaderController controller;

  const _WordToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final word = controller.word;
    return ValueListenableBuilder(
      valueListenable: word.location,
      builder: (context, location, _) => Obx(() {
        // Rebuilds with the zoom so the buttons enable at their limits.
        controller.zoom.value;
        final paged = controller.isPaged.value;
        final pageCount = word.pageCount;
        final page = location.current;
        return ReaderBottomBar(
          above: controller.showPreviews.value && paged && pageCount != null
              ? ReaderPreviewStrip(
                  count: pageCount,
                  current: page,
                  onSelected: word.goTo,
                  itemLabel: 'Page',
                  previewBuilder: (context, number) => ReaderNightModeView(
                    enabled: controller.nightMode.value,
                    paper: true,
                    child: WordPageThumbnail(controller: word, page: number),
                  ),
                )
              : null,
          children: [
            ReaderPreviewsButton(
              tooltip: 'Page thumbnails',
              showing: controller.showPreviews.value && paged,
              onPressed: controller.togglePreviews,
            ),
            ReaderPositionButton(
              label: DocumentViewerStrings.of(context).location(location),
              onPressed: pageCount == null
                  ? null
                  : () async {
                      final target = await showGoToNumberDialog(context, title: 'Go to page', current: page, max: pageCount);
                      if (target != null) word.goTo(target);
                    },
            ),
            ReaderZoomButtons(
              onZoomOut: controller.canZoomOut ? controller.zoomOut : null,
              onZoomIn: controller.canZoomIn ? controller.zoomIn : null,
            ),
            ReaderToolbarButton(
              icon: paged ? Icons.article_outlined : Icons.description_outlined,
              tooltip: paged ? 'Continuous layout' : 'Print layout',
              onPressed: controller.toggleLayout,
            ),
            ReaderNightModeButton(on: controller.nightMode.value, onPressed: controller.toggleNightMode),
            ReaderFullscreenButton(onPressed: controller.toggleFullscreen),
          ],
        );
      }),
    );
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final WordReaderController controller;

  /// Whether the search field (and its result bar below) is showing.
  final bool searching;

  const _ReaderAppBar({required this.controller, required this.searching});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (searching ? 40 : 0));

  @override
  Widget build(BuildContext context) {
    final accent = DocumentCategory.word.accentColor(context);
    final tint = DocumentCategory.word.tintColor(context);

    return AppBar(
      title: Obx(
        () => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: context.titleMedium,
                cursorColor: context.secondary,
                decoration: InputDecoration(
                  hintText: 'Search in document',
                  hintStyle: context.titleMedium?.copyWith(color: context.onSurfaceVariant),
                  border: InputBorder.none,
                ),
                onChanged: controller.onSearchQueryChanged,
                // Enter steps to the next match; the field keeps focus to press again.
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => controller.goToNextMatch(),
                onEditingComplete: () {},
              )
            : Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      DocumentCategory.word.shortCode,
                      style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800, fontSize: 9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(controller.document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
      ),
      actions: [
        Obx(
          () => controller.isSearching.value
              ? IconButton(tooltip: 'Close search', icon: const Icon(Icons.close_rounded), onPressed: controller.stopSearching)
              : IconButton(tooltip: 'Search in document', icon: const Icon(Icons.search_rounded), onPressed: controller.startSearching),
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
          tooltip: 'More actions',
          onSelected: (action) => _handle(action),
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

class _ReaderErrorView extends StatelessWidget {
  final WordReaderController controller;

  const _ReaderErrorView({required this.controller});

  @override
  Widget build(BuildContext context) {
    // BRD §13.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: context.error),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage.value ?? 'This document may be damaged or incomplete.',
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

class _SearchStatusBar extends StatelessWidget {
  final WordReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSearching.value) return const SizedBox.shrink();
      return Container(
        color: context.surfaceContainerLow,
        child: ValueListenableBuilder(
          valueListenable: controller.word.searchState,
          builder: (context, searcher, _) {
            final label = DocumentViewerStrings.of(context).searchStatus(searcher);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant))),
                  IconButton(
                    tooltip: 'Previous match',
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    color: context.onSurfaceVariant,
                    onPressed: searcher.matchCount > 0 ? controller.goToPrevMatch : null,
                  ),
                  IconButton(
                    tooltip: 'Next match',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: context.onSurfaceVariant,
                    onPressed: searcher.matchCount > 0 ? controller.goToNextMatch : null,
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
