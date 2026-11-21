import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What a [HoverSurface] is showing, for its builder.
class SurfaceStates {
  final bool hovered;

  /// Keyboard focus only: a mouse click never turns the ring on.
  final bool focused;
  final bool pressed;
  final bool enabled;

  const SurfaceStates({this.hovered = false, this.focused = false, this.pressed = false, this.enabled = true});
}

/// The 160-200 ms ease-out every desktop Home transition uses.
const homeMotion = Duration(milliseconds: 180);
const homeCurve = Curves.easeOut;

/// A clickable region of desktop Home that draws its own hover, pressed, keyboard-focus and
/// disabled looks through [builder]. Enter / Space activate it when it is focusable; it is a
/// button to screen readers.
class HoverSurface extends StatefulWidget {
  final VoidCallback? onTap;

  /// Right-click, at the pointer's global position.
  final ValueChanged<Offset>? onSecondaryTap;

  /// False keeps it out of Tab traversal (table rows move with the arrow keys instead).
  final bool focusable;
  final String? semanticLabel;
  final bool selected;
  final Widget Function(BuildContext context, SurfaceStates states) builder;

  const HoverSurface({
    super.key,
    required this.onTap,
    required this.builder,
    this.onSecondaryTap,
    this.focusable = true,
    this.semanticLabel,
    this.selected = false,
  });

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final states = SurfaceStates(hovered: _hovered && _enabled, focused: _focused, pressed: _pressed, enabled: _enabled);
    final gestures = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      onSecondaryTapUp:
          widget.onSecondaryTap == null ? null : (details) => widget.onSecondaryTap!(details.globalPosition),
      child: widget.builder(context, states),
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: widget.focusable
          ? FocusableActionDetector(
              enabled: _enabled,
              mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
              onShowHoverHighlight: (value) => setState(() => _hovered = value),
              onShowFocusHighlight: (value) => setState(() => _focused = value),
              child: gestures,
            )
          // Not a Tab stop (table rows): hover only.
          : MouseRegion(
              cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: gestures,
            ),
    );
  }
}

/// The 2 px keyboard-focus ring, drawn outside a [radius]-cornered box.
BoxBorder? focusRing(BuildContext context, SurfaceStates states, {Color? idle}) {
  if (states.focused) return Border.all(color: Theme.of(context).colorScheme.secondary, width: 2);
  return idle == null ? null : Border.all(color: idle);
}
