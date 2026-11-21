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
  ShortcutHelp('Esc', 'Step back or close', noModifier: true),
];

class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, this.onOpenFile, this.onSearch, this.onOpenSettings, this.onEscape, required this.child});

  final VoidCallback? onOpenFile;
  final VoidCallback? onSearch;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onEscape;
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
      },
      // The inner scope keeps this node's autofocus from blocking the
      // child's own: Flutter skips `autofocus` while another node in the same
      // scope holds focus, so a reader's search field opened without its
      // cursor or keyboard. Keys still bubble up here from inside it.
      child: Focus(autofocus: true, child: FocusScope(child: child)),
    );
  }
}
