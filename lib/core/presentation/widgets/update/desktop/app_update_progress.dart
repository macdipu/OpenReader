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
                  Icon(
                    s.phase == UpdatePhase.ready
                        ? Icons.check_circle_rounded
                        : s.phase == UpdatePhase.failed
                            ? Icons.error_outline_rounded
                            : Icons.system_update_rounded,
                    color: s.phase == UpdatePhase.failed
                        ? context.error
                        : context.primary,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(_title(s),
                      style: context.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    _message(s),
                    style: context.bodyMedium
                        ?.copyWith(color: context.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  if (s.phase == UpdatePhase.downloading ||
                      s.phase == UpdatePhase.installing) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: s.phase == UpdatePhase.downloading
                            ? s.progress
                            : null,
                        minHeight: 8,
                      ),
                    ),
                    if (s.phase == UpdatePhase.downloading &&
                        s.progress != null) ...[
                      const SizedBox(height: 8),
                      Text('${(s.progress! * 100).floor()}%',
                          style: context.labelLarge),
                    ],
                  ],
                  const SizedBox(height: 24),
                  ..._actions(s),
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

  List<Widget> _actions(UpdateProgress s) => switch (s.phase) {
        UpdatePhase.downloading => [
            CommonButton.text(title: 'Cancel', onTap: onCancel)
          ],
        UpdatePhase.installing => const [],
        UpdatePhase.ready => [
            CommonButton.filled(title: 'Restart now', onTap: onRestart)
          ],
        UpdatePhase.failed => [
            CommonButton.filled(
                title: 'Download in browser', onTap: onDownloadInBrowser),
            const SizedBox(height: 8),
            CommonButton.text(title: 'Close', onTap: onCancel),
          ],
      };
}
