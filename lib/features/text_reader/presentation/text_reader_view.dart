import 'package:flutter/material.dart';
import '../../file_information/presentation/file_information_view.dart';
import '../../../core/presentation/widgets/reader/reader_menu_extras.dart';
import 'dart:async';
import '../../../core/presentation/widgets/reader/reader_scrollbar.dart';
import '../../../core/presentation/widgets/reader/reader_safe_zone.dart';
import 'package:get/get.dart';

import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/reader/reader_night_mode_view.dart';
import '../../../core/presentation/widgets/reader/reader_toolbar.dart';
import 'package:universal_document_viewer/markdown.dart';
import 'package:universal_document_viewer/plain_text.dart';
import 'markdown/markdown_details_dialog.dart';
import 'text_reader_controller.dart';
import '../../../core/presentation/widgets/app_shortcuts.dart';

/// BRD §9.14 Text Reader Screen.
class TextReaderView extends GetView<TextReaderController> {
  /// Set when the reader is a workspace tab: its controller is registered under this tag.
  final String? tabTag;

  const TextReaderView({super.key, this.tabTag});

  @override
  String? get tag => tabTag;

  @override
  Widget build(BuildContext context) {
    // Scaffold reads appBar.preferredSize only when it builds, so it is rebuilt
    // on search toggle to let the bar collapse back to toolbar height.
    return AppShortcuts(
      // Ctrl/Cmd+F searches; Esc closes search, then the reader (UX-34).
      onSearch: controller.startSearching,
      onEscape: controller.escape,
      onZoomIn: controller.increaseFontSize,
      onZoomOut: controller.decreaseFontSize,
      onZoomReset: controller.resetFontSize,
      onGoTo: () => unawaited(_goToLine(context, controller)),
      onFullscreen: controller.toggleFullscreen,
      child: Obx(() => ReaderNightModeView(
      // The whole reader, bars included, goes dark at night.
      enabled: controller.nightMode.value,
      // A context under the night theme for the whole screen; its own Obx,
      // since the builder runs after the outer one has finished.
      child: Builder(builder: (context) => Obx(() => Scaffold(
      appBar: controller.isFullscreen.value
          ? null
          : _ReaderAppBar(controller: controller, searching: controller.isSearching.value),
      bottomNavigationBar: controller.isFullscreen.value || !controller.status.value.isSuccess
          ? null
          : _TextToolbar(controller: controller),
      body: ReaderFullscreenScope(
        controller: controller,
        child: ContentConstraint(
        maxWidth: ScreenUtils.maxReaderWidth,
        child: Obx(() {
          if (controller.status.value.isBusy) return const LoadingView();
          if (controller.status.value.isError) return _ReaderErrorView(controller: controller);
          if (controller.isMarkdown) return Obx(() => MarkdownView(controller: controller.markdown!, fontSize: controller.fontSize.value));
// The scrollbar needs the kit's scroll controller; the kit should expose it publicly.
// ignore: invalid_use_of_internal_member
          return Obx(() => ReaderSafeZone(kind: ReaderContent.text, child: ReaderScrollbar(controller: controller.textDocument.scrollController, child: PlainTextView(
                controller: controller.textDocument,
                fontSize: controller.fontSize.value,
              ))));
        }),
      ),
      ),
    ))))),
    );
  }
}

/// Line x of N (tap to go to a line) · text size · line wrap · full screen.
class _TextToolbar extends StatelessWidget {
  final TextReaderController controller;

  const _TextToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.lines.length;
      final line = controller.topLine.value.clamp(1, count < 1 ? 1 : count);
      final markdown = controller.isMarkdown;
      // Preview has no lines to count; Code and Split do.
      final showLines = !markdown || controller.viewMode.value != MarkdownViewMode.preview;
      return ReaderBottomBar(
        children: [
          if (showLines)
            ReaderPositionButton(
            label: 'Line $line of $count',
            onPressed: count < 1
                ? null
                : () async {
                    final target = await showGoToNumberDialog(context, title: 'Go to line', current: line, max: count);
                    if (target != null) controller.goToLine(target);
                  },
          ),
          ReaderZoomButtons(
            textSize: true,
            onZoomOut: controller.canDecreaseFontSize ? controller.decreaseFontSize : null,
            onZoomIn: controller.canIncreaseFontSize ? controller.increaseFontSize : null,
          ),
          if (markdown) _ViewModeButton(controller: controller),
          // Markdown's Code mode keeps one line per row so jumps stay exact.
          if (!markdown)
            ReaderToolbarButton(
              icon: Icons.wrap_text_rounded,
              tooltip: controller.lineWrap.value ? 'Don\'t wrap lines' : 'Wrap lines',
              selected: controller.lineWrap.value,
              onPressed: controller.toggleLineWrap,
            ),
          ReaderNightModeButton(on: controller.nightMode.value, onPressed: controller.toggleNightMode),
          ReaderFullscreenButton(onPressed: controller.toggleFullscreen),
        ],
      );
    });
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
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      controller.document.badgeCode,
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
          tooltip: 'More actions',
          onSelected: (action) => _handle(context, action),
          itemBuilder: (context) => [
            if (controller.isMarkdown) ...const [
              PopupMenuItem(value: _ReaderAction.details, child: Text('View details')),
              PopupMenuItem(value: _ReaderAction.copySource, child: Text('Copy source')),
            ],
            const PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            const PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
            PopupMenuItem(value: _ReaderAction.fileInfo, child: Text('File information')),
            if (showInFolderAvailable) PopupMenuItem(value: _ReaderAction.showInFolder, child: Text(showInFolderLabel)),
          ],
        ),
      ],
      bottom: searching
          ? PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller))
          : null,
    );
  }

  void _handle(BuildContext context, _ReaderAction action) {
    switch (action) {
      case _ReaderAction.details:
        showMarkdownDetails(context, document: controller.document, stats: controller.markdownStats!);
      case _ReaderAction.copySource:
        controller.copySource().then((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Source copied'), duration: Duration(seconds: 2)),
            );
          }
        });
      case _ReaderAction.share:
        controller.share();
      case _ReaderAction.openWith:
        controller.openWith();
      case _ReaderAction.fileInfo:
        unawaited(showFileInformationSheet(context, controller.document));
      case _ReaderAction.showInFolder:
        unawaited(showDocumentInFolder(controller.document));
    }
  }
}

enum _ReaderAction { details, copySource, share, openWith, fileInfo, showInFolder }

/// One button for Markdown files that cycles Preview -> Code -> Split -> Preview.
/// Its icon shows the current mode; the tooltip names the next one.
class _ViewModeButton extends StatelessWidget {
  final TextReaderController controller;

  const _ViewModeButton({required this.controller});

  static const _labels = {
    MarkdownViewMode.preview: 'Preview',
    MarkdownViewMode.code: 'Code',
    MarkdownViewMode.split: 'Split',
  };
  static const _icons = {
    MarkdownViewMode.preview: Icons.visibility_outlined,
    MarkdownViewMode.code: Icons.code_rounded,
    MarkdownViewMode.split: Icons.vertical_split_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.viewMode.value;
      final next = MarkdownViewMode.values[(current.index + 1) % MarkdownViewMode.values.length];
      return ReaderToolbarButton(
        icon: _icons[current]!,
        tooltip: '${_labels[current]} view. Switch to ${_labels[next]}',
        onPressed: () => controller.setViewMode(next),
      );
    });
  }
}

class _SearchStatusBar extends StatelessWidget {
  final TextReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSearching.value) return const SizedBox.shrink();
      // Read so this Obx rebuilds as the query and the current match change.
      controller.searchQuery.value;
      controller.currentMatchIndex.value;
      final label = DocumentViewerStrings.of(context).searchStatus(controller.lineSource.searchState.value);
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
                TextButton(onPressed: controller.exitReader, child: const Text('Close')),
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

/// "Go to line" from Ctrl+G; not in Markdown's rendered preview, which has no lines to count.
Future<void> _goToLine(BuildContext context, TextReaderController controller) async {
  final count = controller.lines.length;
  if (count < 1) return;
  if (controller.isMarkdown && controller.viewMode.value == MarkdownViewMode.preview) return;
  final target = await showGoToNumberDialog(
    context,
    title: 'Go to line',
    current: controller.topLine.value.clamp(1, count),
    max: count,
  );
  if (target != null) controller.goToLine(target);
}
