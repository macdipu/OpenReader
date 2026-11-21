import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Reading preferences (ST-04, ST-05, ST-16). They are the same values the reader toolbars change.
/// The PDF reading mode is not here: it is chosen in the PDF reader's own toolbar.
class ReadingSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const ReadingSection({super.key, required this.controller, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final d = SettingsDensity.of(context);
    return SettingsSection(
      label: 'Reading',
      showLabel: showLabel,
      child: Column(
        children: [
          Obx(() => SettingsSwitchRow(
                icon: Icons.nightlight_outlined,
                title: 'Night mode',
                subtitle: 'Dark pages in every reader',
                value: controller.nightMode.value,
                onChanged: controller.setNightMode,
              )),
          const SettingsDivider(),
          SettingsRowLayout(
            icon: Icons.format_size_rounded,
            verticalPadding: 0,
            content: Text('Text size', style: d.titleStyle(context)?.copyWith(color: context.onSurface)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => IconButton(
                      tooltip: 'Smaller text',
                      iconSize: d.isCompact ? 20 : null,
                      constraints: BoxConstraints(minWidth: d.controlHeight, minHeight: d.controlHeight),
                      onPressed: controller.canDecreaseFontSize ? controller.decreaseFontSize : null,
                      icon: const Icon(Icons.remove_rounded),
                    )),
                Obx(() => SizedBox(
                      width: d.isCompact ? 44 : 48,
                      child: Text('${controller.fontSize.value.round()} pt',
                          key: const ValueKey('font-size-value'), textAlign: TextAlign.center, style: context.labelLarge),
                    )),
                Obx(() => IconButton(
                      tooltip: 'Larger text',
                      iconSize: d.isCompact ? 20 : null,
                      constraints: BoxConstraints(minWidth: d.controlHeight, minHeight: d.controlHeight),
                      onPressed: controller.canIncreaseFontSize ? controller.increaseFontSize : null,
                      icon: const Icon(Icons.add_rounded),
                    )),
              ],
            ),
          ),
          const SettingsDivider(),
          Obx(() => SettingsSwitchRow(
                icon: Icons.wrap_text_rounded,
                title: 'Wrap long lines',
                subtitle: 'In text files',
                value: controller.lineWrap.value,
                onChanged: controller.setLineWrap,
              )),
          const SettingsDivider(),
          Obx(() => SettingsSwitchRow(
                icon: Icons.bookmark_outline_rounded,
                title: 'Restore last position',
                subtitle: 'Reopen where you stopped',
                value: controller.restorePosition.value,
                onChanged: controller.setRestorePosition,
              )),
          const SettingsDivider(),
          Obx(() => SettingsSwitchRow(
                icon: Icons.timer_off_outlined,
                title: 'Keep screen awake',
                subtitle: 'While a document is open',
                value: controller.keepScreenAwake.value,
                onChanged: controller.setKeepScreenAwake,
              )),
        ],
      ),
    );
  }
}
