import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts shared by the shell and the readers (CR-OPENREADER-UX
/// UX-34): Ctrl/Cmd+O opens a file, Ctrl/Cmd+F searches, Esc steps back.
/// Both Ctrl and Cmd are bound, so each desktop platform gets its usual key.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, this.onOpenFile, this.onSearch, this.onEscape, required this.child});

  final VoidCallback? onOpenFile;
  final VoidCallback? onSearch;
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
        if (onEscape != null) const SingleActivator(LogicalKeyboardKey.escape): onEscape!,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
