import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/utils/platform_info.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Help & about (ST-10): send feedback (a pre-filled GitHub issue, every platform), rate (Android,
/// where the store page is known), share, version and licenses.
class AboutSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const AboutSection({super.key, required this.controller, this.showLabel = true});

  /// Android and iOS: how to open a file in OpenReader from another app (ST-13). Null on desktop.
  static String? get _openWithTip {
    if (PlatformInfo.isIOS) return 'In Files, touch and hold a document, tap Share, then choose OpenReader.';
    if (PlatformInfo.isAndroid) {
      return 'In a file manager, tap a document and choose OpenReader from "Open with". Pick "Always" to make it the default.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'About',
      footnote: _openWithTip,
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
          Obx(() => SettingsActionRow(
                icon: Icons.info_outline,
                title: 'Version',
                // Tap to ask the store and GitHub; the line under it says what the last check found.
                subtitle: SettingsController.canCheckForUpdates
                    ? (controller.updateSummary.value.isEmpty ? 'Tap to check for updates' : controller.updateSummary.value)
                    : null,
                trailingText: controller.appVersion.value,
                versionStyle: true,
                onTap: SettingsController.canCheckForUpdates ? controller.checkForUpdates : null,
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
