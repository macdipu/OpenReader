import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../core/presentation/utils/screen_utils.dart';
import '../../../../core/presentation/utils/storage_access_help.dart';
import '../../../../core/presentation/widgets/storage_access_steps.dart';
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
                        if (onTap != null) ...[
                          const SizedBox(height: 2),
                          Text('Manage file access', key: const ValueKey('file-access-manage'), style: context.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                        ],
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

  /// Width from which the steps open in a dialog instead of a bottom sheet.
  static const dialogBreakpoint = 600.0;

  Future<void> _show(BuildContext context) {
    Widget content(BuildContext sheet) => _HowToAllowContent(
          controller: controller,
          onDone: () => Navigator.of(sheet).pop(),
          inSheet: context.screenDimensions.width < dialogBreakpoint,
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

class _HowToAllowContent extends StatefulWidget {
  final SettingsController controller;
  final VoidCallback onDone;

  /// A bottom sheet runs under the phone's navigation bar, so it pads for it; a dialog does not.
  final bool inSheet;
  const _HowToAllowContent({required this.controller, required this.onDone, required this.inSheet});

  @override
  State<_HowToAllowContent> createState() => _HowToAllowContentState();
}

class _HowToAllowContentState extends State<_HowToAllowContent> {
  late final Future<StorageAccessHelp> _help = widget.controller.accessHelp();

  @override
  Widget build(BuildContext context) {
    final bottom = widget.inSheet ? MediaQuery.viewPaddingOf(context).bottom + 16 : 20.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(StorageAccessHelp.title, style: context.titleLarge?.copyWith(color: context.onSurface)),
          const SizedBox(height: 8),
          Text(StorageAccessHelp.purpose, style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
          const SizedBox(height: 20),
          FutureBuilder<StorageAccessHelp>(
            future: _help,
            builder: (context, snapshot) {
              final help = snapshot.data;
              if (help == null) return const SizedBox(height: 120);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StorageAccessSteps(help: help),
                  const SizedBox(height: 24),
                  if (help.legacy)
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () {
                        widget.onDone();
                        widget.controller.openAppPermissions();
                      },
                      child: const Text(StorageAccessHelp.openAppSettingsLabel),
                    )
                  else
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () {
                        widget.onDone();
                        widget.controller.openAllFilesAccess();
                      },
                      child: const Text(StorageAccessHelp.openPageLabel),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
