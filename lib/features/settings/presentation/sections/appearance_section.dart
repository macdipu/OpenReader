import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../settings_controller.dart';
import 'settings_widgets.dart';

class AppearanceSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const AppearanceSection({super.key, required this.controller, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'Appearance',
      showLabel: showLabel,
      padded: true,
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
    );
  }
}
