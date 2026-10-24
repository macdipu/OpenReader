import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engines/word/word_model.dart';
import 'word_document_controller.dart';
import 'word_document_layout.dart';
import 'word_widgets.dart';

/// A `.docx` as one continuous, lazily built scrolling document: the first
/// section's header, the text, the last section's footer, then footnotes
/// and endnotes. Search highlights come from
/// [WordDocumentController.searchController], which also drives jumping
/// to the current match. Tapping a note mark shows the note; links open
/// (web links outside the app, `http`/`https`/`mailto` only) or jump to
/// their bookmark.
class WordDocumentView extends StatefulWidget {
  const WordDocumentView({super.key, required this.controller, this.padding = const EdgeInsets.all(16)});

  final WordDocumentController controller;
  final EdgeInsetsGeometry padding;

  @override
  State<WordDocumentView> createState() => _WordDocumentViewState();
}

class _WordDocumentViewState extends State<WordDocumentView> {
  final _anchors = <int, BuildContext>{};

  /// Measured heights of the list items built so far, for estimating where
  /// an unbuilt item is.
  final _itemHeights = <int, double>{};
  int? _lastMatchKey;
  bool _restored = false;

  WordDocumentController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
    controller.searchController.addListener(_onSearchChanged);
    _scheduleRestore();
  }

  @override
  void didUpdateWidget(WordDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      oldWidget.controller.searchController.removeListener(_onSearchChanged);
      controller.addListener(_onControllerChanged);
      controller.searchController.addListener(_onSearchChanged);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleRestore();
  }

  /// Scrolls to the saved offset once the document is on screen. The list
  /// only knows its full length as it builds, so keep trying for a few
  /// frames until the offset is reachable.
  void _scheduleRestore([int attempt = 0]) {
    if (_restored || controller.layout == null) return;
    final target = controller.initialScrollOffset;
    if (target <= 0) {
      _restored = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.scrollController.hasClients) return;
      final position = controller.scrollController.position;
      position.jumpTo(math.min(target, position.maxScrollExtent));
      if (position.pixels >= target - 1 || attempt >= 12) {
        _restored = true;
      } else {
        _scheduleRestore(attempt + 1);
      }
    });
  }

  void _onSearchChanged() {
    final match = controller.searchController.currentMatch;
    if (match == null) {
      _lastMatchKey = null;
      return;
    }
    final key = Object.hash(controller.searchController.query, controller.searchController.currentMatchIndex);
    if (key == _lastMatchKey) return;
    _lastMatchKey = key;
    _jumpToParagraph(match.paragraph);
  }

  /// Brings paragraph [number] into view: directly when it's built,
  /// otherwise by jumping to an estimate first.
  void _jumpToParagraph(int number, [int attempt = 0]) {
    final layout = controller.layout;
    if (layout == null || !mounted) return;
    final anchor = _anchors[number];
    if (anchor != null && anchor.mounted) {
      Scrollable.ensureVisible(anchor, alignment: 0.25, duration: const Duration(milliseconds: 200));
      return;
    }
    if (attempt >= 4 || !controller.scrollController.hasClients) return;
    final item = layout.itemOfParagraph[number];
    final known = _itemHeights.values;
    final average = known.isEmpty ? 48.0 : known.reduce((a, b) => a + b) / known.length;
    var estimate = 0.0;
    for (var i = 0; i < item; i++) {
      estimate += _itemHeights[i] ?? average;
    }
    final position = controller.scrollController.position;
    position.jumpTo(estimate.clamp(0.0, position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToParagraph(number, attempt + 1));
  }

  void _onLink(WordLink link) {
    final anchor = link.anchor;
    final bookmark = anchor == null ? null : controller.layout?.bookmarks[anchor];
    if (bookmark != null) {
      _jumpToParagraph(bookmark);
      return;
    }
    final uri = link.url == null ? null : Uri.tryParse(link.url!);
    if (uri != null && const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _onNote(WordNoteReference reference) {
    final document = controller.document;
    if (document == null) return;
    final blocks = (reference.kind == NoteKind.footnote ? document.footnotes : document.endnotes)[reference.id];
    if (blocks == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => WordScope(
        layout: controller.layout!,
        search: controller.searchController,
        onLink: _onLink,
        onNote: (_) {},
        // Paragraphs in the sheet aren't jump targets.
        anchors: <int, BuildContext>{},
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [for (final block in blocks) WordBlockView(block)],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = controller.layout;
    if (layout == null) return const Center(child: CircularProgressIndicator());
    final firstNote = layout.firstNoteItem;
    final items = layout.items;
    return WordScope(
      layout: layout,
      search: controller.searchController,
      onLink: _onLink,
      onNote: _onNote,
      anchors: _anchors,
      child: NotificationListener<ScrollNotification>(
        // Only the document's own vertical scroll: wide tables scroll
        // sideways inside it.
        onNotification: (notification) {
          if (notification.depth == 0 && notification.metrics.axis == Axis.vertical && _restored) {
            controller.onScrollOffsetChanged(notification.metrics.pixels);
          }
          return false;
        },
        child: ListView.builder(
          controller: controller.scrollController,
          padding: widget.padding,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            Widget child = WordBlockView(item.block);
            if (item.kind == WordItemKind.header || item.kind == WordItemKind.footer) {
              child = DefaultTextStyle.merge(style: const TextStyle(fontSize: 12), child: child);
            }
            final previous = index == 0 ? null : items[index - 1].kind;
            final children = [
              if (index == firstNote) ...[
                const Divider(height: 32),
                Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
              ] else if (item.kind == WordItemKind.footer && previous != WordItemKind.footer)
                const Divider(height: 32),
              child,
              if (item.kind == WordItemKind.header && (index + 1 >= items.length || items[index + 1].kind != WordItemKind.header))
                const Divider(height: 32),
            ];
            return _SizeReporter(
              onSize: (size) => _itemHeights[index] = size.height,
              child: children.length == 1
                  ? child
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            );
          },
        ),
      ),
    );
  }
}

/// Reports its child's laid-out size (for estimating scroll positions).
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}
