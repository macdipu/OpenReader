import 'package:flutter/material.dart';

import '../../../theme/theme_extensions.dart';

/// Centred, width-limited card shared by the desktop update dialogs.
class AppUpdateDialogCard extends StatelessWidget {
  final Widget child;
  const AppUpdateDialogCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: context.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Rounded icon tile shown at the top of the update dialogs.
class AppUpdateIconTile extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;

  const AppUpdateIconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: foreground, size: 34),
    );
  }
}
