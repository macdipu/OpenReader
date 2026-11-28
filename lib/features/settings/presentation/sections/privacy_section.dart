import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../settings_controller.dart';
import 'reset_data_sheet.dart';
import 'settings_widgets.dart';

/// Privacy & data: the privacy policy (ST-06), what the lists show (ST-19) and the two ways to
/// start over, clearing the reading history (ST-07) and resetting every setting. The footnote is
/// only a statement: crash reports and analytics are always on in release builds, with no switch.
class PrivacySection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const PrivacySection({super.key, required this.controller, this.showLabel = true});

  static const statement = 'Documents are processed on this device and never uploaded. '
      'Crash reports and usage analytics tied to a random installation ID are sent to Google Firebase.';

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'Privacy & data',
      showLabel: showLabel,
      footnote: statement,
      child: Column(
        children: [
          SettingsActionRow(
            icon: Icons.policy_outlined,
            title: 'Privacy policy',
            trailing: Icons.open_in_new_rounded,
            onTap: controller.openPrivacyPolicy,
          ),
          const SettingsDivider(),
          Obx(() => SettingsSwitchRow(
                icon: Icons.hide_image_outlined,
                title: 'Hide thumbnails',
                subtitle: 'Show file icons instead of page previews',
                value: controller.hideThumbnails.value,
                onChanged: controller.setHideThumbnails,
              )),
          const SettingsDivider(),
          if (SettingsController.hasSharedCopies) ...[
            Obx(() => SettingsActionRow(
                  icon: Icons.folder_copy_outlined,
                  title: 'Files from other apps',
                  subtitle: '${SettingsController.sharedCopyActionSummary(controller.sharedCopyAction.value)} · '
                      '${SettingsController.formatBytes(controller.sharedCopyBytes.value)} stored',
                  trailing: Icons.chevron_right_rounded,
                  onTap: controller.openSharedFilesSheet,
                )),
            const SettingsDivider(),
          ],
          SettingsActionRow(
            icon: Icons.cleaning_services_outlined,
            title: 'Reset & clear data',
            subtitle: 'Clear your history or reset every setting. Documents are not deleted.',
            trailing: Icons.chevron_right_rounded,
            onTap: () => showResetDataSheet(controller),
          ),
        ],
      ),
    );
  }
}
