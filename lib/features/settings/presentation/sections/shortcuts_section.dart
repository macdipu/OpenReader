import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../core/presentation/widgets/app_shortcuts.dart';
import '../../../../core/presentation/widgets/key_cap.dart';
import 'settings_widgets.dart';

/// Desktop: a read-only table of the keyboard shortcuts (ST-09). Each row is left-aligned: the key
/// cap in a fixed-width column starting at the row's padding, the description right after it.
class ShortcutsSection extends StatelessWidget {
  final bool showLabel;
  const ShortcutsSection({super.key, this.showLabel = true});

  /// Width of the key column at text scale 1 (fits "Ctrl+Shift+Tab").
  static const keyColumnWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final mac = PlatformInfo.isMacOS;
    final d = SettingsDensity.of(context);
    return SettingsSection(
      label: 'Keyboard shortcuts',
      showLabel: showLabel,
      child: LayoutBuilder(builder: (context, box) {
        final keyWidth = MediaQuery.textScalerOf(context).scale(keyColumnWidth);
        // Too narrow for two columns (large text in a small window): the key above its description,
        // still left-aligned.
        final twoColumns = box.maxWidth - 2 * d.horizontalPadding >= keyWidth + 120;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < appShortcutReference.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.outlineVariant),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: d.rowHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: d.horizontalPadding, vertical: d.verticalPadding),
                  child: _row(context, d, i, mac: mac, keyWidth: keyWidth, twoColumns: twoColumns),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _row(BuildContext context, SettingsDensity d, int i,
      {required bool mac, required double keyWidth, required bool twoColumns}) {
    final entry = appShortcutReference[i];
    final keys = Align(
      key: ValueKey('shortcut-keys-$i'),
      alignment: Alignment.centerLeft,
      widthFactor: twoColumns ? null : 1,
      child: KeyCap(entry.label(macOS: mac)),
    );
    final description = Text(entry.description, style: d.titleStyle(context)?.copyWith(color: context.onSurface));
    if (!twoColumns) {
      return Column(
        key: ValueKey('shortcut-row-$i'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [keys, const SizedBox(height: 4), description],
      );
    }
    return Row(
      key: ValueKey('shortcut-row-$i'),
      children: [
        SizedBox(width: keyWidth, child: keys),
        const SizedBox(width: 16),
        Expanded(child: description),
      ],
    );
  }
}
