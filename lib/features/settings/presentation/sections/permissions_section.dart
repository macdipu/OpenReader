import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../core/presentation/utils/screen_utils.dart';
import '../../../../core/presentation/utils/storage_access_flow.dart';
import '../../../../services/utilities/storage_access_service.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Android: live file-access status and the action that fits it (ST-01). iOS: a link to the app's
/// system settings (ST-02), with no status because iOS has no storage permission to report.
///
/// Allowed is one compact row (tap it to manage). Not allowed or blocked adds a filled button, a
/// one-line note on limited mode and a link to the by-hand steps, which open in a sheet.
class PermissionsSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const PermissionsSection({super.key, required this.controller, this.showLabel = true});

  static const limitedModeNote = 'In limited mode OpenReader cannot list your documents on its own.';

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return SettingsSection(
        label: 'Permissions',
        showLabel: showLabel,
        child: Column(
          children: [
            SettingsActionRow(
              icon: Icons.settings_applications_outlined,
              title: 'App permissions',
              subtitle: 'Open OpenReader\'s page in the Settings app',
              trailing: Icons.chevron_right_rounded,
              onTap: controller.openAppPermissions,
            ),
            const SettingsDivider(),
            const SettingsNote('No storage permission is needed. Open documents from the Files app or the Share sheet.'),
          ],
        ),
      );
    }

    return SettingsSection(
      label: 'Permissions',
      showLabel: showLabel,
      child: Obx(() {
        final state = controller.storageState.value;
        // Unreadable: show no status, only the way to the app's settings and the by-hand help.
        if (state == null) {
          return Column(
            children: [
              SettingsActionRow(
                icon: Icons.settings_applications_outlined,
                title: 'App permissions',
                subtitle: 'Open OpenReader\'s page in the Settings app',
                trailing: Icons.chevron_right_rounded,
                onTap: controller.openAppPermissions,
              ),
              Align(alignment: Alignment.centerLeft, child: HowToAllowAccess(controller: controller)),
            ],
          );
        }
        final allowed = state == StorageAccessState.allowed;
        final (status, kind, detail) = switch (state) {
          StorageAccessState.allowed => ('Allowed', SettingsStatusKind.ok, 'OpenReader can find your documents'),
          StorageAccessState.notAllowed => (
              'Not allowed',
              SettingsStatusKind.warning,
              'OpenReader cannot look for documents on its own.'
            ),
          _ => ('Blocked', SettingsStatusKind.blocked, 'Android will not ask again. Allow it in settings.'),
        };
        final row = _FileAccessRow(
          status: status,
          kind: kind,
          detail: detail,
          onTap: allowed ? controller.fixStorageAccess : null,
        );
        if (allowed) return row;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('allow-file-access'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: controller.fixStorageAccess,
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Allow file access'),
                ),
              ),
            ),
            const SettingsNote(limitedModeNote),
            Align(alignment: Alignment.centerLeft, child: HowToAllowAccess(controller: controller)),
          ],
        );
      }),
    );
  }
}

/// Icon, "File access" and a status chip on one title line (the chip drops to the next line as a whole
/// when a large text size leaves no room), the supporting text on the full width, and a chevron when
/// the row opens the OS page.
class _FileAccessRow extends StatelessWidget {
  final String status;
  final SettingsStatusKind kind;
  final String detail;
  final VoidCallback? onTap;
  const _FileAccessRow({required this.status, required this.kind, required this.detail, this.onTap});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: SettingsRowInk(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  const SettingsIconBadge(Icons.folder_open_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('File access', style: context.bodyLarge?.copyWith(color: context.onSurface)),
                            SettingsStatusChip(kind: kind, label: status, textKey: const ValueKey('file-access-status')),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(detail, key: const ValueKey('file-access-detail'), style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text button that opens the by-hand steps for giving file access (Android): a bottom sheet on
/// phones, a dialog on wide windows.
class HowToAllowAccess extends StatelessWidget {
  final SettingsController controller;
  const HowToAllowAccess({super.key, required this.controller});

  static const steps = [
    'Android 11 or newer: open OpenReader\'s All files access page and choose "Allow management of all files" '
        '(not "media only" and not "Don\'t allow").',
    'Android 10 or older: Settings > Apps > OpenReader > Permissions > Storage > Allow.',
  ];

  static const vendorLines = storageAccessVendorLines;

  static const namesDiffer =
      'Names differ a little between phone makers. Come back to OpenReader afterwards: this page updates by itself.';

  /// Width from which the steps open in a dialog instead of a bottom sheet.
  static const dialogBreakpoint = 600.0;

  Future<void> _show(BuildContext context) {
    Widget content(BuildContext sheet) => _HowToAllowContent(
          controller: controller,
          onDone: () => Navigator.of(sheet).pop(),
        );
    if (context.screenDimensions.width >= dialogBreakpoint) {
      return showDialog<void>(
        context: context,
        builder: (dialog) => Dialog(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: content(dialog)),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: TextButton(
        key: const ValueKey('how-to-allow'),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => _show(context),
        child: const Text('How to allow it yourself'),
      ),
    );
  }
}

class _HowToAllowContent extends StatelessWidget {
  final SettingsController controller;
  final VoidCallback onDone;
  const _HowToAllowContent({required this.controller, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to allow file access', style: context.titleMedium?.copyWith(color: context.onSurface)),
          const SizedBox(height: 12),
          for (final step in HowToAllowAccess.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(step, style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
            ),
          for (final line in HowToAllowAccess.vendorLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(HowToAllowAccess.namesDiffer, style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              onDone();
              controller.openAllFilesAccess();
            },
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('Open All files access'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              onDone();
              controller.openAppPermissions();
            },
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open app settings'),
          ),
        ],
      ),
    );
  }
}
