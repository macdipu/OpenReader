import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.contrast_rounded, size: 24, color: context.onSurfaceVariant),
                    const SizedBox(width: 16),
                    Text('Theme', style: context.bodyLarge?.copyWith(color: context.onSurface)),
                  ],
                ),
                const SizedBox(height: 8),
                Obx(() => SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
                          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
                          visualDensity: VisualDensity.standard,
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('Light', maxLines: 1)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark', maxLines: 1)),
                          ButtonSegment(value: ThemeMode.system, label: Text('System', maxLines: 1)),
                        ],
                        selected: {controller.themeController.themeMode},
                        onSelectionChanged: (set) => controller.themeController.changeThemeMode(set.first),
                      ),
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
