import 'package:flutter/material.dart';

import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Data: the two ways to start over, clearing the reading history (ST-07) and resetting every
/// setting. Cache, cache limit and history retention were removed on 2026-11-21 (ST-11, ST-12).
class DataSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const DataSection({super.key, required this.controller, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'Data',
      showLabel: showLabel,
      child: Column(
        children: [
          SettingsActionRow(
            icon: Icons.history_rounded,
            title: 'Clear all history',
            subtitle: 'Removes your recent files. Your documents are not deleted.',
            onTap: controller.clearHistory,
          ),
          const SettingsDivider(),
          SettingsActionRow(
            icon: Icons.restore_rounded,
            title: 'Reset all settings',
            subtitle: 'Puts every setting back to its default.',
            onTap: controller.resetAllSettings,
          ),
        ],
      ),
    );
  }
}
