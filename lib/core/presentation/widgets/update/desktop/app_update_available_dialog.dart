import 'package:flutter/material.dart';

import '../../../theme/theme_extensions.dart';
import '../../buttons/common_button.dart';
import '../../show_dialog/show_dialog.dart';
import 'app_update_dialog_card.dart';

/// Desktop "update available" dialog (Windows / macOS / Linux). Resolves to
/// `true` when the user chooses to update, `false`/`null` for "Later" or a dismiss.
Future<bool?> showAppUpdateAvailableDialog({required String message, String actionLabel = 'Update now'}) =>
    showAppDialog<bool>(child: AppUpdateAvailableDialog(message: message, actionLabel: actionLabel));

class AppUpdateAvailableDialog extends StatelessWidget {
  final String message;
  final String actionLabel;

  const AppUpdateAvailableDialog({super.key, required this.message, this.actionLabel = 'Update now'});

  @override
  Widget build(BuildContext context) {
    return AppUpdateDialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Text(message, style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CommonButton.filled(title: actionLabel, onTap: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 8),
          CommonButton.text(title: 'Later', onTap: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
  }
}
