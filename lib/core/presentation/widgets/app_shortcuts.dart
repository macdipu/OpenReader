import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts shared by the shell and the readers (CR-OPENREADER-UX
/// UX-34): Ctrl/Cmd+O opens a file, Ctrl/Cmd+F searches, Ctrl/Cmd+, opens
/// Settings, Esc steps back.
/// Both Ctrl and Cmd are bound, so each desktop platform gets its usual key.
class ShortcutHelp {
  /// The key, e.g. `O` or `Tab`.
  final String key;
  final String description;

  /// True when the shortcut uses Ctrl (and Cmd on macOS); false for Ctrl on every platform.
  final bool cmdOnMac;
  final bool shift;
  final bool noModifier;
  const ShortcutHelp(this.key, this.description, {this.cmdOnMac = true, this.shift = false, this.noModifier = false});

  /// The shortcut as shown, e.g. `Cmd+O` on macOS and `Ctrl+O` elsewhere.
  String label({required bool macOS}) {
    if (noModifier) return key;
    final mod = macOS && cmdOnMac ? 'Cmd' : 'Ctrl';
    return '$mod+${shift ? 'Shift+' : ''}$key';
  }
}

/// Every desktop shortcut, in the order Settings lists them. Keep in step with the bindings in
/// [AppShortcuts] and in `AppShell`.
const appShortcutReference = <ShortcutHelp>[
  ShortcutHelp('O', 'Open a file'),
  ShortcutHelp('F', 'Search'),
  ShortcutHelp(',', 'Open Settings'),
  ShortcutHelp('B', 'Show or hide the sidebar'),
  ShortcutHelp('W', 'Close the open document tab', cmdOnMac: false),
  ShortcutHelp('Tab', 'Next document tab', cmdOnMac: false),
  ShortcutHelp('Tab', 'Previous document tab', cmdOnMac: false, shift: true),
  ShortcutHelp('\\', 'Split the document tabs side by side', cmdOnMac: false),
  ShortcutHelp('+', 'Zoom in (text size in a text file)'),
  ShortcutHelp('-', 'Zoom out'),
  ShortcutHelp('0', 'Back to page width / normal size'),
  ShortcutHelp('G', 'Go to a page, slide, line or cell', cmdOnMac: false),
  ShortcutHelp('PageUp / PageDown', 'Previous or next page or slide', noModifier: true),
  ShortcutHelp('Home / End', 'First or last page or slide', noModifier: true),
  ShortcutHelp('F11', 'Full screen', noModifier: true),
  ShortcutHelp('Esc', 'Step back or close', noModifier: true),
];

class AppShortcuts extends StatelessWidget {
  const AppShortcuts({
    super.key,
    this.onOpenFile,
    this.onSearch,
    this.onOpenSettings,
    this.onEscape,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomReset,
    this.onGoTo,
    this.onPreviousPage,
    this.onNextPage,
    this.onFirstPage,
    this.onLastPage,
    this.onFullscreen,
    required this.child,
  });

  final VoidCallback? onOpenFile;
  final VoidCallback? onSearch;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onEscape;

  /// Reader shortcuts. Each is bound only when the reader passes it, so a reader without the action
  /// leaves the key alone. Ctrl and Cmd are both bound, as for the others.
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomReset;
  final VoidCallback? onGoTo;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onFirstPage;
  final VoidCallback? onLastPage;
  final VoidCallback? onFullscreen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (onOpenFile != null) ...{
          const SingleActivator(LogicalKeyboardKey.keyO, control: true): onOpenFile!,
          const SingleActivator(LogicalKeyboardKey.keyO, meta: true): onOpenFile!,
        },
        if (onSearch != null) ...{
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): onSearch!,
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): onSearch!,
        },
        if (onOpenSettings != null) ...{
          const SingleActivator(LogicalKeyboardKey.comma, control: true): onOpenSettings!,
          const SingleActivator(LogicalKeyboardKey.comma, meta: true): onOpenSettings!,
        },
        if (onEscape != null) const SingleActivator(LogicalKeyboardKey.escape): onEscape!,
        if (onZoomIn != null) ...{
          for (final control in [true, false])
            for (final key in [LogicalKeyboardKey.equal, LogicalKeyboardKey.add, LogicalKeyboardKey.numpadAdd])
              for (final shift in [false, true])
                SingleActivator(key, control: control, meta: !control, shift: shift): onZoomIn!,
        },
        if (onZoomOut != null) ...{
          for (final control in [true, false])
            for (final key in [LogicalKeyboardKey.minus, LogicalKeyboardKey.numpadSubtract])
              SingleActivator(key, control: control, meta: !control): onZoomOut!,
        },
        if (onZoomReset != null) ...{
          for (final control in [true, false])
            for (final key in [LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0])
              SingleActivator(key, control: control, meta: !control): onZoomReset!,
        },
        // Cmd+G is "find next" on a Mac, so go-to is Ctrl+G there.
        if (onGoTo != null) const SingleActivator(LogicalKeyboardKey.keyG, control: true): onGoTo!,
        if (onPreviousPage != null) const SingleActivator(LogicalKeyboardKey.pageUp): onPreviousPage!,
        if (onNextPage != null) const SingleActivator(LogicalKeyboardKey.pageDown): onNextPage!,
        if (onFirstPage != null) const SingleActivator(LogicalKeyboardKey.home): onFirstPage!,
        if (onLastPage != null) const SingleActivator(LogicalKeyboardKey.end): onLastPage!,
        if (onFullscreen != null) const SingleActivator(LogicalKeyboardKey.f11): onFullscreen!,
      },
      // The inner scope keeps this node's autofocus from blocking the
      // child's own: Flutter skips `autofocus` while another node in the same
      // scope holds focus, so a reader's search field opened without its
      // cursor or keyboard. Keys still bubble up here from inside it.
      child: Focus(autofocus: true, child: FocusScope(child: child)),
    );
  }
}
