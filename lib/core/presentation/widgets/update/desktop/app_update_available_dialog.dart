import 'package:flutter/material.dart';

import '../../../theme/theme_extensions.dart';
import '../../buttons/common_button.dart';
import '../../show_dialog/show_dialog.dart';
import 'app_update_dialog_card.dart';

/// Desktop "update available" dialog (Windows / macOS / Linux). Resolves to
/// `true` when the user chooses to update, `false`/`null` for "Later" or a dismiss.
Future<bool?> showAppUpdateAvailableDialog({
  required String message,
  String actionLabel = 'Update now',
  String? version,
}) =>
    showAppDialog<bool>(
        child: AppUpdateAvailableDialog(
            message: message, actionLabel: actionLabel, version: version));

class AppUpdateAvailableDialog extends StatelessWidget {
  final String message;
  final String actionLabel;
  final String? version;

  const AppUpdateAvailableDialog(
      {super.key, required this.message, this.actionLabel = 'Update now', this.version});

  @override
  Widget build(BuildContext context) {
    return AppUpdateDialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppUpdateIconTile(
            icon: Icons.system_update_rounded,
            background: context.primaryContainer,
            foreground: context.onPrimaryContainer,
          ),
          const SizedBox(height: 20),
          Text('Update available', style: context.headlineSmall, textAlign: TextAlign.center),
          if (version != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: ShapeDecoration(
                color: context.primary.withValues(alpha: 0.1),
                shape: const StadiumBorder(),
              ),
              child: Text(
                version!,
                style: context.labelLarge?.copyWith(
                  color: context.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(message,
              style:
                  context.bodyMedium?.copyWith(color: context.onSurfaceVariant, height: 1.45),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CommonButton.filled(
            title: actionLabel,
            onTap: () => Navigator.of(context).pop(true),
            leading: Icon(Icons.download_rounded, color: context.onPrimary, size: 20),
            borderRadius: 14,
          ),
          const SizedBox(height: 4),
          CommonButton.ghost(title: 'Later', onTap: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
  }
}
