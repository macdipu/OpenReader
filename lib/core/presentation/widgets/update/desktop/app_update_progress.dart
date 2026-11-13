import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/theme_extensions.dart';
import '../../buttons/common_button.dart';
import '../../show_dialog/show_dialog.dart';
import 'app_update_dialog_card.dart';

enum UpdatePhase { downloading, installing, ready, failed }

class UpdateProgress {
  final UpdatePhase phase;

  /// 0..1 while downloading; null when the size is unknown.
  final double? progress;
  final String? error;

  const UpdateProgress(this.phase, {this.progress, this.error});
}

/// Non-dismissible desktop dialog for the in-app desktop update: download progress,
/// then a Restart button once the new build is staged.
/// Shows [AppUpdateProgress]; resolves when it is closed.
Future<void> showAppUpdateProgress(AppUpdateProgress dialog) => showAppDialog<void>(dismissible: false, child: dialog);

class AppUpdateProgress extends StatelessWidget {
  final ValueListenable<UpdateProgress> state;
  final String version;
  final VoidCallback onCancel;
  final VoidCallback onRestart;
  final VoidCallback onDownloadInBrowser;

  const AppUpdateProgress({
    super.key,
    required this.state,
    required this.version,
    required this.onCancel,
    required this.onRestart,
    required this.onDownloadInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AppUpdateDialogCard(
        child: ValueListenableBuilder<UpdateProgress>(
          valueListenable: state,
          builder: (context, s, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppUpdateIconTile(
                icon: switch (s.phase) {
                  UpdatePhase.ready => Icons.check_circle_rounded,
                  UpdatePhase.failed => Icons.error_outline_rounded,
                  _ => Icons.downloading_rounded,
                },
                background: s.phase == UpdatePhase.failed
                    ? context.error.withValues(alpha: 0.14)
                    : s.phase == UpdatePhase.ready
                        ? context.primaryContainer
                        : context.primary.withValues(alpha: 0.12),
                foreground: s.phase == UpdatePhase.failed
                    ? context.error
                    : s.phase == UpdatePhase.ready
                        ? context.onPrimaryContainer
                        : context.primary,
              ),
              const SizedBox(height: 20),
              Text(_title(s),
                  style: context.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _message(s),
                style: context.bodyMedium
                    ?.copyWith(color: context.onSurfaceVariant, height: 1.45),
                textAlign: TextAlign.center,
              ),
              if (s.phase == UpdatePhase.downloading ||
                  s.phase == UpdatePhase.installing) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress',
                        style: context.labelMedium
                            ?.copyWith(color: context.onSurfaceVariant)),
                    Text(
                      s.phase == UpdatePhase.downloading && s.progress != null
                          ? '${(s.progress! * 100).floor()}%'
                          : '...',
                      style: context.labelLarge?.copyWith(
                        color: context.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: s.phase == UpdatePhase.downloading
                        ? s.progress
                        : null,
                    minHeight: 10,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ..._actions(context, s),
            ],
          ),
        ),
      ),
    );
  }

  String _title(UpdateProgress s) => switch (s.phase) {
        UpdatePhase.downloading => 'Downloading OpenReader $version',
        UpdatePhase.installing => 'Installing update',
        UpdatePhase.ready => 'Update installed',
        UpdatePhase.failed => 'Update failed',
      };

  String _message(UpdateProgress s) => switch (s.phase) {
        UpdatePhase.downloading => 'Keep reading - this only takes a moment.',
        UpdatePhase.installing => 'Preparing the new version...',
        UpdatePhase.ready => 'Restart OpenReader to start using $version.',
        UpdatePhase.failed => s.error ?? 'Something went wrong.',
      };

  List<Widget> _actions(BuildContext context, UpdateProgress s) => switch (s.phase) {
        UpdatePhase.downloading => [
            CommonButton.ghost(title: 'Cancel', onTap: onCancel)
          ],
        UpdatePhase.installing => const [],
        UpdatePhase.ready => [
            CommonButton.filled(
                title: 'Restart now',
                onTap: onRestart,
                leading: Icon(Icons.restart_alt_rounded, color: context.onPrimary, size: 20),
                borderRadius: 14)
          ],
        UpdatePhase.failed => [
            CommonButton.filled(
                title: 'Download in browser',
                onTap: onDownloadInBrowser,
                borderRadius: 14),
            const SizedBox(height: 4),
            CommonButton.ghost(title: 'Close', onTap: onCancel),
          ],
      };
}
