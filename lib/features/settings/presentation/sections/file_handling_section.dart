import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../services/platform_integration/default_app_service.dart';
import '../settings_controller.dart';
import 'settings_widgets.dart';

/// Desktop: which document types open in OpenReader, and how to change that (ST-03, ST-14, ST-15).
///
/// One card holding a compact table: a header row ("Open these files with OpenReader" and Set all),
/// then one line per type with its icon, name and extension, a fixed-width status column and a
/// fixed-width action column (Set, or an empty space of the same width when it is already the
/// default), so every status and every button sits at the same x. A type whose status cannot be read
/// shows no status, only its button. Under the card: the Windows system settings link and Ask me again.
class FileHandlingSection extends StatelessWidget {
  final SettingsController controller;
  final bool showLabel;
  const FileHandlingSection({super.key, required this.controller, this.showLabel = true});

  static const headerTitle = 'Open these files with OpenReader';

  /// Column widths at text scale 1.
  static const statusColumnWidth = 104.0;
  static const actionColumnWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    final d = SettingsDensity.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final statusWidth = statusColumnWidth * scale;
    final actionWidth = actionColumnWidth * scale;
    final buttonStyle = TextButton.styleFrom(
      minimumSize: Size(d.isCompact ? 56 : 64, d.controlHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: d.isCompact ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
      visualDensity: d.isCompact ? VisualDensity.compact : VisualDensity.standard,
    );

    return SettingsSection(
      label: 'File handling',
      showLabel: showLabel,
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (PlatformInfo.isWindows)
              TextButton.icon(
                key: const ValueKey('open-system-default-apps'),
                style: buttonStyle,
                onPressed: controller.openSystemDefaultAppsSettings,
                icon: Icon(Icons.open_in_new_rounded, size: d.trailingIconSize),
                label: const Text('Open system default-apps settings'),
              ),
            Tooltip(
              message: 'Show the first-run offer to make OpenReader your default reader',
              child: TextButton.icon(
                key: const ValueKey('ask-default-again'),
                style: buttonStyle,
                onPressed: controller.askAboutDefaultAgain,
                icon: Icon(Icons.notifications_active_outlined, size: d.trailingIconSize),
                label: const Text('Ask me again'),
              ),
            ),
          ],
        ),
      ),
      child: LayoutBuilder(builder: (context, box) {
        // Status in its own column when there is room; otherwise (large text in a narrow window) it
        // goes under the name and only the action column stays on the right.
        final statusColumn = box.maxWidth >= d.textInset + 120 * scale + statusWidth + actionWidth + d.horizontalPadding;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(d.horizontalPadding, 6, d.horizontalPadding - 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(headerTitle,
                          style: d.titleStyle(context)?.copyWith(color: context.onSurface, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Obx(() {
                    final allDefault = DocumentType.values
                        .every((t) => controller.defaultStatuses[t] == DefaultStatus.isDefault);
                    return TextButton(
                      key: const ValueKey('set-all-defaults'),
                      style: buttonStyle,
                      // Nothing left to change when every type already opens in OpenReader.
                      onPressed: allDefault ? null : () => controller.makeDefault(DocumentType.values.toSet()),
                      child: const Text('Set all', semanticsLabel: 'Set OpenReader as default for every type'),
                    );
                  }),
                ],
              ),
            ),
            const SettingsDivider(fullWidth: true),
            for (final type in DocumentType.values) ...[
              if (type != DocumentType.values.first) const SettingsDivider(),
              Obx(() => _TypeRow(
                    type: type,
                    status: controller.defaultStatuses[type] ?? DefaultStatus.unknown,
                    onSet: () => controller.makeDefault({type}),
                    density: d,
                    statusWidth: statusColumn ? statusWidth : null,
                    actionWidth: actionWidth,
                    buttonStyle: buttonStyle,
                  )),
            ],
          ],
        );
      }),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final DocumentType type;
  final DefaultStatus status;
  final VoidCallback onSet;
  final SettingsDensity density;

  /// Width of the status column; null puts the status under the name.
  final double? statusWidth;
  final double actionWidth;
  final ButtonStyle buttonStyle;

  const _TypeRow({
    required this.type,
    required this.status,
    required this.onSet,
    required this.density,
    required this.statusWidth,
    required this.actionWidth,
    required this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final d = density;
    final (label, kind) = switch (status) {
      DefaultStatus.isDefault => ('Default', SettingsStatusKind.ok),
      DefaultStatus.otherApp => ('Other app', SettingsStatusKind.neutral),
      DefaultStatus.unknown => (null, SettingsStatusKind.neutral),
    };
    final statusWidget = label == null
        ? null
        : SettingsStatus(kind: kind, label: label, textKey: ValueKey('default-status-${type.name}'));
    final name = Text.rich(
      TextSpan(children: [
        TextSpan(text: type.label, style: TextStyle(color: context.onSurface)),
        TextSpan(text: '  .${type.extension}', style: TextStyle(color: context.onSurfaceVariant)),
      ]),
      style: d.titleStyle(context),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: d.rowHeight),
      child: Padding(
        padding: EdgeInsets.only(left: d.horizontalPadding, right: d.horizontalPadding - 4),
        child: Row(
          children: [
            // Type and status are read as one item; the Set button stays its own action.
            Expanded(
              child: MergeSemantics(
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: d.iconSize, color: context.onSurfaceVariant),
                    SizedBox(width: d.iconGap),
                    Expanded(
                      child: statusWidth != null || statusWidget == null
                          ? name
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [name, statusWidget],
                              ),
                            ),
                    ),
                    if (statusWidth != null)
                      SizedBox(
                        key: ValueKey('file-type-status-${type.name}'),
                        width: statusWidth,
                        child: Align(alignment: Alignment.centerLeft, child: statusWidget),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              key: ValueKey('file-type-action-${type.name}'),
              width: actionWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: status == DefaultStatus.isDefault
                    ? null
                    : TextButton(
                        key: ValueKey('set-default-${type.name}'),
                        onPressed: onSet,
                        style: buttonStyle,
                        child: Text('Set', semanticsLabel: 'Set OpenReader as default for ${type.label}'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
