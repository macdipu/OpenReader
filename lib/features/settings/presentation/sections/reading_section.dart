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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SettingsIconBadge(Icons.format_size_rounded),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Text size', style: context.bodyLarge?.copyWith(color: context.onSurface))),
                    Obx(() => IconButton(
                          tooltip: 'Smaller text',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          onPressed: controller.canDecreaseFontSize ? controller.decreaseFontSize : null,
                          icon: const Icon(Icons.remove_rounded),
                        )),
                    Obx(() => SizedBox(
                          width: 48,
                          child: Text('${controller.fontSize.value.round()} pt',
                              key: const ValueKey('font-size-value'), textAlign: TextAlign.center, style: context.labelLarge),
                        )),
                    Obx(() => IconButton(
                          tooltip: 'Larger text',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          onPressed: controller.canIncreaseFontSize ? controller.increaseFontSize : null,
                          icon: const Icon(Icons.add_rounded),
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                Obx(() => Text(
                      'The quick brown fox jumps over the lazy dog.',
                      key: const ValueKey('font-sample'),
                      softWrap: controller.lineWrap.value,
                      overflow: TextOverflow.clip,
                      style: TextStyle(fontSize: controller.fontSize.value, color: context.onSurface),
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
                subtitle: 'Reopen documents where you stopped reading',
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
