import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// A scrolling strip of page (or slide) previews above a reader's toolbar,
/// matching the PDF reader's thumbnail strip: the current one outlined and
/// kept centred, the ones either side in view, a tap jumps to one.
class ReaderPreviewStrip extends StatefulWidget {
  final int count;

  /// 1-based.
  final int current;
  final ValueChanged<int> onSelected;

  /// The preview of item [number] (1-based).
  final Widget Function(BuildContext context, int number) previewBuilder;

  /// Each preview's width; pages are portrait, slides landscape.
  final double itemWidth;

  /// What an item is, for its semantic label ("Page", "Slide").
  final String itemLabel;

  const ReaderPreviewStrip({
    super.key,
    required this.count,
    required this.current,
    required this.onSelected,
    required this.previewBuilder,
    required this.itemLabel,
    this.itemWidth = 70,
  });

  @override
  State<ReaderPreviewStrip> createState() => _ReaderPreviewStripState();
}

class _ReaderPreviewStripState extends State<ReaderPreviewStrip> {
  final _scrollController = ScrollController();

  /// One preview plus 4 padding each side.
  double get _itemExtent => widget.itemWidth + 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centreCurrent(animate: false));
  }

  @override
  void didUpdateWidget(ReaderPreviewStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centreCurrent(animate: true));
    }
  }

  void _centreCurrent({required bool animate}) {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (8 + (widget.current - 1) * _itemExtent + _itemExtent / 2 - position.viewportDimension / 2)
        .clamp(0.0, position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  void dispose() {
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
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: widget.count,
        itemBuilder: (context, index) {
          final number = index + 1;
          final selected = number == widget.current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              button: true,
              selected: selected,
              label: '${widget.itemLabel} $number',
              child: GestureDetector(
                onTap: () => widget.onSelected(number),
                child: Container(
                  width: widget.itemWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: selected ? context.secondary : Colors.transparent, width: 2),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: widget.previewBuilder(context, number)),
                      Text('$number', style: context.labelSmall?.copyWith(color: context.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
