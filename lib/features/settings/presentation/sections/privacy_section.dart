import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../settings_controller.dart';
import 'settings_widgets.dart';

/// What leaves the device and the privacy policy (ST-06), and what the lists show (ST-19). The statement is only a
/// statement: crash reports and analytics are always on in release builds, with no switch.
class PrivacySection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const PrivacySection({super.key, required this.controller, this.showLabel = true});

  static const statement = 'Your documents are processed on this device and are never uploaded. '
      'Crash reports and usage analytics (tied to a random installation identifier, never to your '
      'documents) are always collected and sent to Google Firebase in release builds. Debug builds send nothing.';

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'Privacy',
      showLabel: showLabel,
      child: Column(
        children: [
          const SettingsNote(statement),
          const SettingsDivider(),
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
                subtitle: 'Show the file type icon instead of a page preview in Recents and Home',
                value: controller.hideThumbnails.value,
                onChanged: controller.setHideThumbnails,
              )),
        ],
      ),
    );
  }
}
