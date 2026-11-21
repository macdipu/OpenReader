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
    final d = SettingsDensity.of(context);
    return SettingsSection(
      label: 'Appearance',
      showLabel: showLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, box) {
            // Desktop with room for it: one 40px row, the control on the right at desktop size.
            // Otherwise (phones, narrow windows, large text): the title over a full-width control.
            final oneRow = d.isCompact && box.maxWidth >= MediaQuery.textScalerOf(context).scale(240) + 140;
            if (oneRow) {
              return SettingsRowLayout(
                icon: Icons.contrast_rounded,
                content: Text('Theme', style: d.titleStyle(context)?.copyWith(color: context.onSurface)),
                trailing: Obx(() => _themeControl(compact: true)),
              );
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(d.horizontalPadding, 12, d.horizontalPadding, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.contrast_rounded, size: d.iconSize, color: context.onSurfaceVariant),
                      SizedBox(width: d.iconGap),
                      Text('Theme', style: d.titleStyle(context)?.copyWith(color: context.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(() => SizedBox(width: double.infinity, child: _themeControl(compact: d.isCompact))),
                ],
              ),
            );
          }),
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

  /// Light / Dark / System. Comfortable: full width, 48dp. Compact (desktop): 32px tall, sized to
  /// its labels, still at least a 32px pointer target per segment.
  Widget _themeControl({required bool compact}) => SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(compact ? const Size(64, 32) : const Size.fromHeight(48)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: compact ? 12 : 4)),
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
        ),
        segments: const [
          ButtonSegment(value: ThemeMode.light, label: Text('Light', maxLines: 1)),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark', maxLines: 1)),
          ButtonSegment(value: ThemeMode.system, label: Text('System', maxLines: 1)),
        ],
        selected: {controller.themeController.themeMode},
        onSelectionChanged: (set) => controller.themeController.changeThemeMode(set.first),
      );

  /// Android takes the palette from the wallpaper; desktops offer only their accent colour.
  static String get dynamicColorTitle => PlatformInfo.isAndroid ? 'Use wallpaper colours' : 'Use accent colour';
  static String get dynamicColorSubtitle =>
      PlatformInfo.isAndroid ? 'Match the app to your wallpaper' : 'Match the app to your system accent colour';
}
