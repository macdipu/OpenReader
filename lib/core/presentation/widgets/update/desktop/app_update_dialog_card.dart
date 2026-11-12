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
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(color: context.surfaceContainerLowest, borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
}
