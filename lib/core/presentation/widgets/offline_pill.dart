import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// "OFFLINE" status pill (CR-OPENREADER-UX UX-23). Replaces the former
/// "SANDBOXED" pill, which contradicted the All Files Access the app uses;
/// "offline" is the claim that holds - OpenReader makes no network calls.
class OfflinePill extends StatelessWidget {
  const OfflinePill({super.key, this.showIcon = true});

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Offline: OpenReader makes no network calls',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(Icons.cloud_off_outlined, size: 12, color: context.secondary),
              const SizedBox(width: 4),
            ],
            Text('OFFLINE', style: context.monoMetadata),
          ],
        ),
      ),
    );
  }
}
