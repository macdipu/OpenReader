import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../services/platform_integration/default_app_service.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Desktop: which document types open in OpenReader, and how to change that (ST-03, ST-14, ST-15).
/// A type whose status cannot be read shows no status, only its button.
class FileHandlingSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const FileHandlingSection({super.key, required this.controller, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      label: 'File handling',
      showLabel: showLabel,
      child: Column(
        children: [
          const SettingsNote('Choose which documents open in OpenReader when you double-click them.'),
          for (final type in DocumentType.values) ...[
            const SettingsDivider(),
            Obx(() => _TypeRow(
                  type: type,
                  status: controller.defaultStatuses[type] ?? DefaultStatus.unknown,
                  onSet: () => controller.makeDefault({type}),
                )),
          ],
          const SettingsDivider(),
          SettingsActionRow(
            icon: Icons.done_all_rounded,
            title: 'Set all',
            subtitle: 'Open every supported type in OpenReader',
            onTap: () => controller.makeDefault(DocumentType.values.toSet()),
          ),
          if (PlatformInfo.isWindows) ...[
            const SettingsDivider(),
            SettingsActionRow(
              icon: Icons.open_in_new_rounded,
              title: 'Open system default-apps settings',
              trailing: Icons.open_in_new_rounded,
              onTap: controller.openSystemDefaultAppsSettings,
            ),
          ],
          const SettingsDivider(),
          SettingsActionRow(
            icon: Icons.notifications_active_outlined,
            title: 'Ask me again',
            subtitle: 'Show the first-run offer to make OpenReader your default reader',
            onTap: controller.askAboutDefaultAgain,
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final DocumentType type;
  final DefaultStatus status;
  final VoidCallback onSet;
  const _TypeRow({required this.type, required this.status, required this.onSet});

  @override
  Widget build(BuildContext context) {
    final (label, kind) = switch (status) {
      DefaultStatus.isDefault => ('Default', SettingsStatusKind.ok),
      DefaultStatus.otherApp => ('Other app', SettingsStatusKind.neutral),
      DefaultStatus.unknown => (null, SettingsStatusKind.neutral),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Type and status are read as one item; the Set button stays its own action.
          Expanded(
            child: MergeSemantics(
              child: Row(
                children: [
                  const SettingsIconBadge(Icons.description_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.label, style: context.bodyLarge?.copyWith(color: context.onSurface)),
                        Text('.${type.extension}', style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (label != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SettingsStatus(kind: kind, label: label, textKey: ValueKey('default-status-${type.name}')),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (status != DefaultStatus.isDefault)
            TextButton(
              key: ValueKey('set-default-${type.name}'),
              onPressed: onSet,
              style: TextButton.styleFrom(minimumSize: const Size(64, 48), visualDensity: VisualDensity.standard),
              child: Text('Set', semanticsLabel: 'Set OpenReader as default for ${type.label}'),
            ),
        ],
      ),
    );
  }
}
