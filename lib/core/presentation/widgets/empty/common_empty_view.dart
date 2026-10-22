import 'package:flutter/material.dart';
import '../../theme/theme_extensions.dart';

/// Empty state: icon, message, optional subtitle and an action that gets the
/// user out of it (CR-OPENREADER-UX UX-29 - previously bare text). Always
/// scrollable, so it also works under a `RefreshIndicator`.
class CommonEmptyView extends StatelessWidget {
  final String? message;
  final IconData icon;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CommonEmptyView({
    super.key,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Icon(icon, size: 56, color: context.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          message ?? 'Nothing here',
          textAlign: TextAlign.center,
          style: context.titleMedium?.copyWith(color: context.onSurface),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Center(child: FilledButton(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}
