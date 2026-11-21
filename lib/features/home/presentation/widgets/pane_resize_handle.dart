import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import 'hover_surface.dart';

/// The divider between desktop Home's list and its inspector. Drag it to resize the inspector,
/// double-click it to reset the width; with keyboard focus, Left widens and Right narrows the
/// inspector (it sits on the right).
class PaneResizeHandle extends StatefulWidget {
  /// The inspector's current width.
  final double width;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onResize;
  final VoidCallback onReset;

  const PaneResizeHandle({
    super.key,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onResize,
    required this.onReset,
  });

  /// One arrow-key press.
  static const step = 16.0;

  /// The hit area; the line drawn in it is 1 px.
  static const extent = 8.0;

  @override
  State<PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends State<PaneResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging || _focused;
    return Semantics(
      label: 'Resize details pane',
      value: '${widget.width.round()} pixels',
      increasedValue: '${(widget.width + PaneResizeHandle.step).clamp(widget.minWidth, widget.maxWidth).round()} pixels',
      decreasedValue: '${(widget.width - PaneResizeHandle.step).clamp(widget.minWidth, widget.maxWidth).round()} pixels',
      onIncrease: () => widget.onResize(widget.width + PaneResizeHandle.step),
      onDecrease: () => widget.onResize(widget.width - PaneResizeHandle.step),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.resizeColumn,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _ResizeIntent(PaneResizeHandle.step),
          SingleActivator(LogicalKeyboardKey.arrowRight): _ResizeIntent(-PaneResizeHandle.step),
        },
        actions: {
          _ResizeIntent: CallbackAction<_ResizeIntent>(onInvoke: (intent) => widget.onResize(widget.width + intent.delta)),
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onReset()),
        },
        child: GestureDetector(
          key: const ValueKey('home-inspector-resize'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          // The inspector is to the right: dragging left makes it wider.
          onHorizontalDragUpdate: (details) => widget.onResize(widget.width - details.delta.dx),
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onHorizontalDragCancel: () => setState(() => _dragging = false),
          onDoubleTap: widget.onReset,
          child: SizedBox(
            width: PaneResizeHandle.extent,
            child: Center(
              child: AnimatedContainer(
                duration: homeMotion,
                curve: homeCurve,
                width: active ? 2 : 1,
                color: active ? context.secondary : context.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeIntent extends Intent {
  final double delta;
  const _ResizeIntent(this.delta);
}
