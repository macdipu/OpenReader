import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Help & about (ST-10): send feedback (a pre-filled GitHub issue, every platform), rate (Android,
/// where the store page is known), share, the welcome screens, version and licenses.
class AboutSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const AboutSection({super.key, required this.controller, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'Help & about',
      showLabel: showLabel,
      child: Column(
        children: [
          SettingsActionRow(
            icon: Icons.feedback_outlined,
            title: 'Send feedback',
            subtitle: 'Opens a GitHub issue (needs a free GitHub account)',
            trailing: Icons.open_in_new_rounded,
            onTap: controller.sendFeedback,
          ),
          const SettingsDivider(),
          if (SettingsController.canRateApp) ...[
            SettingsActionRow(
              icon: Icons.star_outline_rounded,
              title: 'Rate OpenReader',
              subtitle: 'Opens the Play Store',
              trailing: Icons.open_in_new_rounded,
              onTap: controller.rateApp,
            ),
            const SettingsDivider(),
          ],
          SettingsActionRow(
            icon: Icons.ios_share_rounded,
            title: 'Share app',
            trailing: Icons.chevron_right_rounded,
            onTap: controller.shareApp,
          ),
          const SettingsDivider(),
          SettingsActionRow(
            icon: Icons.waving_hand_outlined,
            title: 'Show welcome screens again',
            onTap: controller.showWelcomeAgain,
          ),
          const SettingsDivider(),
          Obx(() => SettingsActionRow(
                icon: Icons.info_outline,
                title: 'Version',
                trailingText: controller.appVersion.value,
                versionStyle: true,
              )),
          const SettingsDivider(),
          SettingsActionRow(
            icon: Icons.description_outlined,
            title: 'Open-source licenses',
            trailing: Icons.chevron_right_rounded,
            onTap: () => showLicensePage(context: context, applicationName: 'OpenReader'),
          ),
        ],
      ),
    );
  }
}
