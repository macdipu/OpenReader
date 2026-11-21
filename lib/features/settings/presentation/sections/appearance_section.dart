import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/utils/platform_info.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Theme (ST-01) and dynamic colour (ST-20). The dynamic colour switch appears only where the
/// system offers a palette: the wallpaper colours on Android 12+, the accent colour on desktop.
class AppearanceSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const AppearanceSection({super.key, required this.controller, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'Appearance',
      showLabel: showLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // With the card's own 4, the 12 the theme block always had.
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsBlockHeader(icon: Icons.contrast_rounded, title: 'Theme'),
                const SizedBox(height: 10),
                Obx(() => SettingsSegmented<ThemeMode>(
                      value: controller.themeController.themeMode,
                      choices: const [
                        SettingsChoice(ThemeMode.light, 'Light', icon: Icons.light_mode_outlined),
                        SettingsChoice(ThemeMode.dark, 'Dark', icon: Icons.dark_mode_outlined),
                        SettingsChoice(ThemeMode.system, 'System', icon: Icons.brightness_auto_outlined),
                      ],
                      onChanged: controller.themeController.changeThemeMode,
                    )),
              ],
            ),
          ),
          Obx(() {
            if (!controller.dynamicColorAvailable) return const SizedBox.shrink();
            return Column(
              children: [
                const SettingsDivider(),
                SettingsSwitchRow(
                  icon: Icons.palette_outlined,
                  title: dynamicColorTitle,
                  subtitle: dynamicColorSubtitle,
                  value: controller.useDynamicColor.value,
                  onChanged: controller.setUseDynamicColor,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Android takes the palette from the wallpaper; desktops offer only their accent colour.
  static String get dynamicColorTitle => PlatformInfo.isAndroid ? 'Use wallpaper colours' : 'Use accent colour';
  static String get dynamicColorSubtitle =>
      PlatformInfo.isAndroid ? 'Match the app to your wallpaper' : 'Match the app to your system accent colour';
}
