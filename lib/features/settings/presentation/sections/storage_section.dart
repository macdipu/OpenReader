import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/file_size_formatter.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Reading history, the render cache, and their limits (ST-07, ST-11, ST-12).
class StorageSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const StorageSection({super.key, required this.controller, this.showLabel = true});

  static String capLabel(int? mb) => mb == null ? 'No limit' : (mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB');
  static String retentionLabel(int? days) => days == null ? 'Forever' : (days == 0 ? 'Off' : '$days days');

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'Files & storage',
      showLabel: showLabel,
      bare: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionCard(
            child: SettingsActionRow(
              icon: Icons.history_rounded,
              title: 'Clear reading history',
              subtitle: 'Your documents are not deleted',
              onTap: controller.clearHistory,
            ),
          ),
          const SizedBox(height: 12),
          SettingsSectionCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsBlockHeader(
                  icon: Icons.manage_history_rounded,
                  title: 'Keep reading history',
                  subtitle: 'Older entries are removed. Off stops recording what you open and where you stopped reading.',
                ),
                const SizedBox(height: 10),
                Obx(() => SettingsSegmented<int?>(
                      value: controller.historyRetentionDays.value,
                      choices: [
                        for (final days in SettingsController.retentionChoices) SettingsChoice(days, retentionLabel(days)),
                      ],
                      onChanged: controller.setHistoryRetention,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => SettingsStatBento(
                icon: Icons.cleaning_services_outlined,
                value: controller.isLoadingStats.value ? '—' : formatFileSize(controller.cacheSizeBytes.value),
                label: 'cached render tiles',
                actionLabel: 'Clear render cache',
                destructive: true,
                onAction: controller.confirmClearCache,
              )),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'The cache holds page images and thumbnails OpenReader prepares so documents open faster. '
              'It is safe to clear: it is rebuilt as you read.',
              style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          SettingsSectionCard(
            child: Obx(() => SettingsPickerRow<int?>(
                  key: const ValueKey('cache-cap-picker'),
                  icon: Icons.data_usage_rounded,
                  title: 'Cache size limit',
                  subtitle: 'Past this, the oldest files are removed first',
                  value: controller.cacheCapMb.value,
                  choices: [
                    for (final mb in SettingsController.cacheCapChoices) SettingsChoice(mb, capLabel(mb)),
                  ],
                  onChanged: controller.setCacheCap,
                )),
          ),
        ],
      ),
    );
  }
}
