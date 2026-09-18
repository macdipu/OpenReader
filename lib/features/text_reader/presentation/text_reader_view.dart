import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'text_reader_controller.dart';

/// BRD §9.14 Text Reader Screen.
class TextReaderView extends GetView<TextReaderController> {
  const TextReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReaderAppBar(controller: controller),
      body: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.status.value.isError) return _ReaderErrorView(controller: controller);
        return _TextBody(controller: controller);
      }),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lines = widget.controller.lines;
      final query = widget.controller.searchQuery.value;
      return ListView.builder(
        controller: widget.controller.scrollController,
        itemCount: lines.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: _TextLine(
            text: lines[index],
            fontSize: widget.controller.fontSize.value,
            wrap: widget.controller.lineWrap.value,
            highlightQuery: query,
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize);
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
        style: TextStyle(backgroundColor: Colors.orange.withValues(alpha: 0.5)),
      ));
      start = index + query.length;
    }
    return TextSpan(style: style, children: spans);
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextReaderController controller;

  const _ReaderAppBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Obx(
        () => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: context.titleMedium,
                decoration: const InputDecoration(hintText: 'Search in document', border: InputBorder.none),
                onChanged: controller.search,
              )
            : Text(controller.document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      actions: [
        Obx(
          () => controller.isSearching.value
              ? IconButton(icon: const Icon(Icons.close), onPressed: controller.stopSearching)
              : IconButton(icon: const Icon(Icons.search), onPressed: controller.startSearching),
        ),
        Obx(
          () => IconButton(
            icon: Icon(controller.isFavorite ? Icons.favorite : Icons.favorite_border),
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
      bottom: PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller)),
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
        // BRD §13.
        label = 'No searchable text found.';
      } else {
        label = '${controller.currentMatchIndex.value + 1} of ${controller.matches.length} result(s)';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.bodySmall)),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: controller.matches.isNotEmpty ? controller.goToPrevMatch : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
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
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 16),
            Text(controller.errorMessage.value ?? 'This document may be damaged or incomplete.', textAlign: TextAlign.center),
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
