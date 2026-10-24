import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'package:universal_document_viewer/text.dart';
import 'text_reader_controller.dart';
import '../../../core/presentation/widgets/app_shortcuts.dart';

/// BRD §9.14 Text Reader Screen.
class TextReaderView extends GetView<TextReaderController> {
  const TextReaderView({super.key});

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
      body: ContentConstraint(
        maxWidth: ScreenUtils.maxReaderWidth,
        child: Obx(() {
          if (controller.status.value.isBusy) return const LoadingView();
          if (controller.status.value.isError) return _ReaderErrorView(controller: controller);
          return Obx(() => TextDocumentView(
                controller: controller.textDocument,
                fontSize: controller.fontSize.value,
                wrap: controller.lineWrap.value,
              ));
        }),
      ),
    )),
    );
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextReaderController controller;

  /// Whether the search field (and its result bar below) is showing.
  final bool searching;

  const _ReaderAppBar({required this.controller, required this.searching});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (searching ? 40 : 0));

  @override
  Widget build(BuildContext context) {
    final accent = DocumentCategory.text.accentColor(context);
    final tint = DocumentCategory.text.tintColor(context);

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
                onChanged: controller.search,
              )
            : Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      DocumentCategory.text.shortCode,
                      style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
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
            PopupMenuItem(value: _ReaderAction.increaseFontSize, child: Text('Increase Text Size')),
            PopupMenuItem(value: _ReaderAction.decreaseFontSize, child: Text('Decrease Text Size')),
            PopupMenuItem(value: _ReaderAction.toggleLineWrap, child: Text('Toggle Line Wrap')),
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
      case _ReaderAction.increaseFontSize:
        controller.increaseFontSize();
      case _ReaderAction.decreaseFontSize:
        controller.decreaseFontSize();
      case _ReaderAction.toggleLineWrap:
        controller.toggleLineWrap();
    }
  }
}

enum _ReaderAction { share, openWith, increaseFontSize, decreaseFontSize, toggleLineWrap }

class _SearchStatusBar extends StatelessWidget {
  final TextReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSearching.value) return const SizedBox.shrink();
      final String label;
      if (controller.searchQuery.value.isEmpty) {
        label = '';
      } else if (controller.matches.isEmpty) {
        // Zero matches in readable text. BRD's 'No searchable text found'
        // is reserved for text-less (scanned) PDFs.
        label = 'No matches';
      } else {
        label = '${controller.currentMatchIndex.value + 1} of ${controller.matches.length} result(s)';
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.surfaceContainerLow,
          border: Border(top: BorderSide(color: context.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant))),
            IconButton(
              tooltip: 'Previous match',
              icon: Icon(Icons.keyboard_arrow_up_rounded, color: context.onSurfaceVariant),
              onPressed: controller.matches.isNotEmpty ? controller.goToPrevMatch : null,
            ),
            IconButton(
              tooltip: 'Next match',
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.onSurfaceVariant),
              onPressed: controller.matches.isNotEmpty ? controller.goToNextMatch : null,
            ),
          ],
        ),
      );
    });
  }
}

class _ReaderErrorView extends StatelessWidget {
  final TextReaderController controller;

  const _ReaderErrorView({required this.controller});

  @override
  Widget build(BuildContext context) {
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
