import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../services/utilities/storage_access_service.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Android: live file-access status and the action that fits it (ST-01). iOS: a link to the app's
/// system settings (ST-02), with no status because iOS has no storage permission to report.
class PermissionsSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const PermissionsSection({super.key, required this.controller, this.showLabel = true});

  static const limitedModeNote = 'In limited mode OpenReader cannot list the documents on your device by itself. '
      'You can still open a file from your Files app, from the Share sheet, or with Open file.';

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return SettingsSection(
        label: 'Permissions',
        showLabel: showLabel,
        child: Column(
          children: [
            SettingsActionRow(
              icon: Icons.settings_applications_outlined,
              title: 'App permissions',
              subtitle: 'Open OpenReader\'s page in the Settings app',
              trailing: Icons.chevron_right_rounded,
              onTap: controller.openAppPermissions,
            ),
            const SettingsDivider(),
            const SettingsNote(
                'OpenReader needs no storage permission on iPhone or iPad. Open documents from the Files app or the Share sheet.'),
          ],
        ),
      );
    }

    return SettingsSection(
      label: 'Permissions',
      showLabel: showLabel,
      child: Obx(() {
        final state = controller.storageState.value;
        // Unreadable: show no status, only the way to the app's settings.
        if (state == null) {
          return Column(
            children: [
              SettingsActionRow(
                icon: Icons.settings_applications_outlined,
                title: 'App permissions',
                subtitle: 'Open OpenReader\'s page in the Settings app',
                trailing: Icons.chevron_right_rounded,
                onTap: controller.openAppPermissions,
              ),
              const SettingsDivider(),
              HowToAllowAccess(controller: controller),
            ],
          );
        }
        final (status, kind, detail, action) = switch (state) {
          StorageAccessState.allowed => (
              'Allowed',
              SettingsStatusKind.ok,
              'OpenReader can find the documents on your device.',
              'Manage in app settings'
            ),
          StorageAccessState.notAllowed => (
              'Not allowed (limited mode)',
              SettingsStatusKind.warning,
              'OpenReader cannot look for documents on its own.',
              'Allow file access'
            ),
          _ => (
              'Blocked',
              SettingsStatusKind.blocked,
              'Android will not ask again. Allow it in the app settings.',
              'Open settings to allow'
            ),
        };
        return Column(
          children: [
            MergeSemantics(
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const SettingsIconBadge(Icons.folder_open_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('File access', style: context.bodyLarge?.copyWith(color: context.onSurface)),
                        const SizedBox(height: 2),
                        Text(detail, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SettingsStatus(
                      kind: kind,
                      label: status,
                      textAlign: TextAlign.end,
                      textKey: const ValueKey('file-access-status'),
                    ),
                  ),
                ],
              ),
            ),
            ),
            const SettingsDivider(),
            SettingsActionRow(
              icon: state == StorageAccessState.allowed ? Icons.tune_rounded : Icons.lock_open_rounded,
              title: action,
              trailing: Icons.chevron_right_rounded,
              onTap: controller.fixStorageAccess,
            ),
            const SettingsDivider(),
            const SettingsNote(limitedModeNote),
            const SettingsDivider(),
            HowToAllowAccess(controller: controller, initiallyExpanded: state == StorageAccessState.blocked),
          ],
        );
      }),
    );
  }
}

/// Help for giving file access by hand (Android), with a button that opens the right page.
class HowToAllowAccess extends StatelessWidget {
  final SettingsController controller;
  final bool initiallyExpanded;
  const HowToAllowAccess({super.key, required this.controller, this.initiallyExpanded = false});

  static const steps = [
    'Android 11 or newer: Settings > Apps > OpenReader > Permissions > Files and media (or All files access) > Allow. '
        'Or Settings > Apps > Special app access > All files access > OpenReader > Allow.',
    'Android 10 or older: Settings > Apps > OpenReader > Permissions > Storage > Allow.',
    'The names differ a little between phone makers. Come back to OpenReader afterwards: this page updates by itself.',
  ];

  @override
  Widget build(BuildContext context) {
    // The card paints a decoration; ListTile needs its own Material to draw ink on.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
        key: ValueKey('how-to-allow-$initiallyExpanded'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: const SettingsIconBadge(Icons.help_outline_rounded),
        title: Text('How to allow it yourself', style: context.bodyLarge?.copyWith(color: context.onSurface)),
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(step, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.openAllFilesAccess,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Open All files access'),
              ),
              OutlinedButton.icon(
                onPressed: controller.openAppPermissions,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open app settings'),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}
