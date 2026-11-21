import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// A keyboard shortcut drawn as a key cap ("Ctrl+O", "⌘O"). The label uses the UI font (labelLarge,
/// Inter in both themes), never the monospace metadata font, so the letter O cannot be read as a zero.
class KeyCap extends StatelessWidget {
  final String label;

  /// Smaller text and padding, for a chip inside a button.
  final bool dense;

  /// Text colour; onSurfaceVariant when null.
  final Color? foreground;

  /// Fill; surfaceContainerLow when null. Pass [Colors.transparent] for a cap on a filled button.
  final Color? background;

  /// Outline; outlineVariant when null.
  final Color? borderColor;

  const KeyCap(this.label, {super.key, this.dense = false, this.foreground, this.background, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 7, vertical: dense ? 0 : 2),
      decoration: BoxDecoration(
        color: background ?? context.surfaceContainerLow,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor ?? context.outlineVariant),
      ),
      child: Text(
        label,
        style: context.labelLarge?.copyWith(
          color: foreground ?? context.onSurfaceVariant,
          fontSize: dense ? 11 : 12,
          letterSpacing: 0.2,
          height: 16 / 12,
        ),
      ),
    );
  }
}
