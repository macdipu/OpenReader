import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/reader_fullscreen.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/screen_utils.dart';

/// The floating pill every reader shows at the bottom (first drawn for the
/// PDF reader, DESIGN_SPEC.md #09). Each reader fills it in the same order:
/// position (tap to jump) · zoom out/in · its own tools · full screen.
class ReaderToolbar extends StatelessWidget {
  final List<Widget> children;

  const ReaderToolbar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.outlineVariant),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: context.shadow.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      // Scales down rather than overflowing on narrow phones (UX-31/33).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// [ReaderToolbar] as a Scaffold's `bottomNavigationBar`, for readers whose
/// content doesn't scroll under it.
class ReaderBottomBar extends StatelessWidget {
  final List<Widget> children;

  /// Shown above the toolbar when set, e.g. a [ReaderPreviewStrip].
  final Widget? above;

  const ReaderBottomBar({super.key, required this.children, this.above});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        // Slimmer on a short (landscape) screen so the page keeps its height.
        padding: EdgeInsets.fromLTRB(12, 4, 12, context.isShortScreen ? 6 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (above case final above?) Padding(padding: const EdgeInsets.only(bottom: 8), child: above),
            Center(heightFactor: 1, child: ReaderToolbar(children: children)),
          ],
        ),
      ),
    );
  }
}

/// The first tool in a paged reader's toolbar: shows or hides its
/// [ReaderPreviewStrip].
class ReaderPreviewsButton extends StatelessWidget {
  final bool showing;
  final String tooltip;
  final VoidCallback? onPressed;

  const ReaderPreviewsButton({super.key, required this.showing, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) =>
      ReaderToolbarButton(icon: Icons.grid_view_rounded, tooltip: tooltip, selected: showing, onPressed: onPressed);
}

/// One tool in a [ReaderToolbar]. [selected] tints it, for a mode that's on.
class ReaderToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  const ReaderToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      isSelected: selected,
      icon: Icon(icon, color: selected ? context.secondary : context.onSurfaceVariant, size: 20),
      onPressed: onPressed,
    );
  }
}

/// Where the reader is ("Page 3 of 12"); tapping it jumps elsewhere.
class ReaderPositionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const ReaderPositionButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final style = context.labelMedium?.copyWith(color: context.onSurface);
    return TextButton(onPressed: onPressed, child: Text(label, style: style));
  }
}

/// The zoom-out and zoom-in pair every reader has.
class ReaderZoomButtons extends StatelessWidget {
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;

  /// For text readers, whose "zoom" is the text size.
  final bool textSize;

  const ReaderZoomButtons({super.key, required this.onZoomOut, required this.onZoomIn, this.textSize = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReaderToolbarButton(
          icon: textSize ? Icons.text_decrease_rounded : Icons.zoom_out_rounded,
          tooltip: textSize ? 'Smaller text' : 'Zoom out',
          onPressed: onZoomOut,
        ),
        ReaderToolbarButton(
          icon: textSize ? Icons.text_increase_rounded : Icons.zoom_in_rounded,
          tooltip: textSize ? 'Larger text' : 'Zoom in',
          onPressed: onZoomIn,
        ),
      ],
    );
  }
}

/// Night mode, just before full screen in every [ReaderToolbar].
class ReaderNightModeButton extends StatelessWidget {
  final bool on;
  final VoidCallback onPressed;

  const ReaderNightModeButton({super.key, required this.on, required this.onPressed});

  @override
  Widget build(BuildContext context) => ReaderToolbarButton(
        icon: on ? Icons.dark_mode_rounded : Icons.dark_mode_outlined,
        tooltip: on ? 'Turn off night mode' : 'Night mode',
        selected: on,
        onPressed: onPressed,
      );
}

/// The last tool in every [ReaderToolbar].
class ReaderFullscreenButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ReaderFullscreenButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) =>
      ReaderToolbarButton(icon: Icons.fullscreen_rounded, tooltip: 'Full screen', onPressed: onPressed);
}

/// Wraps a reader's body: in full screen, a small button in the corner
/// brings the bars back, and system Back leaves full screen before it
/// leaves the reader.
class ReaderFullscreenScope extends StatelessWidget {
  final ReaderFullscreen controller;
  final Widget child;

  const ReaderFullscreenScope({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fullscreen = controller.isFullscreen.value;
      return PopScope(
        canPop: !fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.setFullscreen(false);
        },
        child: Stack(
          children: [
            Positioned.fill(child: child),
            if (fullscreen)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton.filledTonal(
                      tooltip: 'Exit full screen',
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                      onPressed: () => controller.setFullscreen(false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Asks for a number from 1 to [max] ("Go to page"); null when cancelled
/// or not a number.
Future<int?> showGoToNumberDialog(
  BuildContext context, {
  required String title,
  required int current,
  required int max,
}) async {
  final value = await showDialog<int>(
    context: context,
    builder: (context) => _GoToNumberDialog(title: title, current: current, max: max),
  );
  return value?.clamp(1, max);
}

class _GoToNumberDialog extends StatefulWidget {
  final String title;
  final int current;
  final int max;

  const _GoToNumberDialog({required this.title, required this.current, required this.max});

  @override
  State<_GoToNumberDialog> createState() => _GoToNumberDialogState();
}

/// Owns the field's controller, which the closing animation still uses
/// after the dialog's result is in.
class _GoToNumberDialogState extends State<_GoToNumberDialog> {
  late final _text = TextEditingController(text: '${widget.current}');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(int.tryParse(_text.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: '1–${widget.max}'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Go')),
      ],
    );
  }
}
