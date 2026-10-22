import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'text_line_metrics.dart';
import 'text_reader_controller.dart';

/// BRD §9.14 Text Reader Screen.
class TextReaderView extends GetView<TextReaderController> {
  const TextReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold reads appBar.preferredSize only when it builds, so it is rebuilt
    // on search toggle to let the bar collapse back to toolbar height.
    return Obx(() => Scaffold(
      appBar: _ReaderAppBar(controller: controller, searching: controller.isSearching.value),
      body: ContentConstraint(
        maxWidth: ScreenUtils.maxReaderWidth,
        child: Obx(() {
          if (controller.status.value.isBusy) return const LoadingView();
          if (controller.status.value.isError) return _ReaderErrorView(controller: controller);
          return _TextBody(controller: controller);
        }),
      ),
    ));
  }
}

class _TextBody extends StatefulWidget {
  final TextReaderController controller;

  const _TextBody({required this.controller});

  @override
  State<_TextBody> createState() => _TextBodyState();
}

class _TextBodyState extends State<_TextBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreInitialOffset());
    widget.controller.scrollController.addListener(_onScroll);
  }

  void _onScroll() => widget.controller.onScrolled(widget.controller.scrollController.offset);

  void _restoreInitialOffset() {
    final controller = widget.controller;
    if (controller.scrollController.hasClients && controller.initialScrollOffset > 0) {
      final max = controller.scrollController.position.maxScrollExtent;
      controller.scrollController.jumpTo(controller.initialScrollOffset.clamp(0.0, max));
    }
  }

  @override
  void dispose() {
    widget.controller.scrollController.removeListener(_onScroll);
    widget.controller.lineOffsetResolver = null;
    super.dispose();
  }

  static const _rowPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 2);

  TextLineMetrics? _metrics;

  /// Keeps the controller's jump-to-match offsets measured against what is
  /// actually laid out (UX-21); re-measured only when an input changes.
  void _attachMetrics(BuildContext context, double width, double fontSize, bool wrap) {
    final lines = widget.controller.lines;
    // No bold-text merge: jumps only happen with a search query, when rows
    // render via `Text.rich` with this explicit-weight style, which the
    // system bold-text setting doesn't override.
    final style = DefaultTextStyle.of(context).style.merge(_TextLine.styleFor(context, fontSize));
    final textScaler = MediaQuery.textScalerOf(context);
    final contentWidth = width - _rowPadding.horizontal;
    final current = _metrics;
    if (current == null ||
        !current.matches(lines: lines, style: style, textScaler: textScaler, contentWidth: contentWidth, wrap: wrap)) {
      _metrics = TextLineMetrics(
        lines: lines,
        style: style,
        textScaler: textScaler,
        contentWidth: contentWidth,
        wrap: wrap,
        verticalPadding: _rowPadding.vertical,
      );
    }
    widget.controller.lineOffsetResolver = _metrics!.offsetOf;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lines = widget.controller.lines;
      final query = widget.controller.searchQuery.value;
      final fontSize = widget.controller.fontSize.value;
      final wrap = widget.controller.lineWrap.value;
      return Container(
        color: context.surface,
        child: LayoutBuilder(builder: (context, constraints) {
          _attachMetrics(context, constraints.maxWidth, fontSize, wrap);
          return ListView.builder(
            controller: widget.controller.scrollController,
            itemCount: lines.length,
            itemBuilder: (context, index) => Padding(
              padding: _rowPadding,
              child: _TextLine(
                text: lines[index],
                fontSize: fontSize,
                wrap: wrap,
                highlightQuery: query,
              ),
            ),
          );
        }),
      );
    });
  }
}

class _TextLine extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool wrap;
  final String highlightQuery;

  const _TextLine({required this.text, required this.fontSize, required this.wrap, required this.highlightQuery});

  /// Shared with [TextLineMetrics] measurement, which must match it.
  static TextStyle styleFor(BuildContext context, double fontSize) =>
      context.bodyMedium?.copyWith(fontSize: fontSize, color: context.onSurface) ??
      TextStyle(fontSize: fontSize, color: context.onSurface);

  @override
  Widget build(BuildContext context) {
    final style = styleFor(context, fontSize);
    final content = highlightQuery.isEmpty
        ? Text(text, style: style, softWrap: wrap, overflow: wrap ? TextOverflow.visible : TextOverflow.clip)
        : Text.rich(_highlighted(text, highlightQuery, style, context), softWrap: wrap, overflow: wrap ? TextOverflow.visible : TextOverflow.clip);
    return wrap ? content : SingleChildScrollView(scrollDirection: Axis.horizontal, child: content);
  }

  TextSpan _highlighted(String text, String query, TextStyle style, BuildContext context) {
    final lower = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(backgroundColor: context.secondaryContainer, color: context.onSecondaryContainer),
      ));
      start = index + query.length;
    }
    return TextSpan(style: style, children: spans);
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
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: controller.stopSearching)
              : IconButton(icon: const Icon(Icons.search_rounded), onPressed: controller.startSearching),
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
              icon: Icon(Icons.keyboard_arrow_up_rounded, color: context.onSurfaceVariant),
              onPressed: controller.matches.isNotEmpty ? controller.goToPrevMatch : null,
            ),
            IconButton(
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
