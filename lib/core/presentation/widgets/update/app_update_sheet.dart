import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import '../app_sheet/show_app_sheet.dart';
import '../buttons/common_button.dart';

/// "Update available" sheet. Resolves to `true` when the user chooses to
/// update, `false`/`null` for "Later" or a dismiss.
Future<bool?> showAppUpdateSheet({required String message, String actionLabel = 'Update now'}) =>
    showAppSheet<bool>(child: AppUpdateSheet(message: message, actionLabel: actionLabel));

class AppUpdateSheet extends StatelessWidget {
  final String message;
  final String actionLabel;

  const AppUpdateSheet({super.key, required this.message, this.actionLabel = 'Update now'});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.outlineVariant, borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: context.primaryContainer, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.system_update_rounded, color: context.onPrimaryContainer, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Update available', style: context.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message,
                style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CommonButton.filled(title: actionLabel, onTap: () => Navigator.of(context).pop(true)),
              const SizedBox(height: 8),
              CommonButton.text(title: 'Later', onTap: () => Navigator.of(context).pop(false)),
            ],
          ),
        ),
      ),
    );
  }
}
