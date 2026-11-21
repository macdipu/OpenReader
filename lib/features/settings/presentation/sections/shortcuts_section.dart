import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../core/presentation/widgets/app_shortcuts.dart';
import 'settings_widgets.dart';

/// Desktop: a read-only list of the keyboard shortcuts (ST-09).
class ShortcutsSection extends StatelessWidget {
  final bool showLabel;
  const ShortcutsSection({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final mac = PlatformInfo.isMacOS;
    return SettingsSection(
      label: 'Keyboard shortcuts',
      showLabel: showLabel,
      child: Column(
        children: [
          for (var i = 0; i < appShortcutReference.length; i++) ...[
            if (i > 0) const SettingsDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              // A Wrap, so that at large text sizes the key moves under the description.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 6,
                spacing: 12,
                children: [
                  Text(appShortcutReference[i].description, style: context.bodyLarge?.copyWith(color: context.onSurface)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: context.surfaceContainerLow, borderRadius: BorderRadius.circular(6)),
                    child: Text(appShortcutReference[i].label(macOS: mac), style: context.monoMetadata),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
