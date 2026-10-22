import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
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
      onEscape: () => controller.isSearching.value ? controller.stopSearching() : Get.back(),
      child: Obx(() => Scaffold(
      appBar: _ReaderAppBar(controller: controller, searching: controller.isSearching.value),
      body: Obx(() {
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
            child: NotificationListener<ScrollNotification>(
              // Only the document's own vertical scroll: wide tables scroll
              // horizontally inside it and used to overwrite the saved offset.
              onNotification: (notification) {
                if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
                  controller.onScrollOffsetChanged(notification.metrics.pixels);
                }
                return false;
              },
              // DocxView's scroll view has no controller of its own, so it
              // adopts this one - on every platform, not only mobile -
              // which is how the reading position is restored (UX-22).
              child: PrimaryScrollController(
                controller: controller.scrollController,
                automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DocxView(
                    bytes: controller.validatedBytes!,
                    searchController: controller.searchController,
                    onLoaded: controller.onDocumentLoaded,
                    onError: controller.onLoadError,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    )),
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
        child: ListenableBuilder(
          listenable: controller.searchController,
          builder: (context, _) {
            final searcher = controller.searchController;
            final String label;
            if (searcher.query.isEmpty) {
              label = '';
            } else if (searcher.matchCount == 0) {
              // Zero matches in readable text. BRD's 'No searchable text found'
              // is reserved for text-less (scanned) PDFs.
              label = 'No matches';
            } else {
              label = '${searcher.currentMatchIndex + 1} of ${searcher.matchCount} result(s)';
            }
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
