import 'package:flutter/material.dart';

import '../../../../core/presentation/utils/platform_info.dart';
import 'settings_widgets.dart';

/// Android and iOS: how to open a file in OpenReader from another app (ST-13).
class OpenWithSection extends StatelessWidget {
  final bool showLabel;
  const OpenWithSection({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final tip = PlatformInfo.isIOS
        ? 'In the Files app, touch and hold a document, choose Share, then pick OpenReader.'
        : 'In your file manager or another app, tap a document, then choose OpenReader from "Open with". '
            'Choose "Always" to make it the default for that type.';
    return SettingsSection(
      label: 'Open with',
      showLabel: showLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(12, 12, 0, 12), child: SettingsIconBadge(Icons.lightbulb_outline_rounded)),
          Expanded(child: SettingsNote(tip)),
        ],
      ),
    );
  }
}
