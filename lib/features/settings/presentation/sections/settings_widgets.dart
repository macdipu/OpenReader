import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';

/// How dense the Settings rows are. Phones and tablets are [comfortable] (touch: 48/56dp rows, 24dp
/// icons, bodyLarge titles); desktop (macOS, Windows, Linux) is [compact] (pointer: 40/52px rows,
/// 20px icons, bodyMedium titles, 32px controls).
enum SettingsDensity {
  comfortable(
    rowHeight: 48,
    rowHeightWithSubtitle: 56,
    iconSize: 24,
    iconGap: 16,
    horizontalPadding: 16,
    verticalPadding: 8,
    controlHeight: 48,
    trailingIconSize: 24,
    statusIconSize: 18,
  ),
  compact(
    rowHeight: 40,
    rowHeightWithSubtitle: 52,
    iconSize: 20,
    iconGap: 12,
    horizontalPadding: 12,
    verticalPadding: 6,
    controlHeight: 32,
    trailingIconSize: 18,
    statusIconSize: 16,
  );

  /// Minimum row height without and with a supporting line.
  final double rowHeight;
  final double rowHeightWithSubtitle;

  /// The leading icon and the gap between it and the text.
  final double iconSize;
  final double iconGap;
  final double horizontalPadding;
  final double verticalPadding;

  /// Height of buttons, steppers and segmented controls (also their minimum pointer target).
  final double controlHeight;
  final double trailingIconSize;
  final double statusIconSize;

  const SettingsDensity({
    required this.rowHeight,
    required this.rowHeightWithSubtitle,
    required this.iconSize,
    required this.iconGap,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.controlHeight,
    required this.trailingIconSize,
    required this.statusIconSize,
  });

  bool get isCompact => this == compact;

  /// Where a row's text starts: past the padding, the icon and the gap (dividers are inset to it).
  double get textInset => horizontalPadding + iconSize + iconGap;

  /// The density for this platform: [compact] on desktop, [comfortable] on phones and tablets.
  static SettingsDensity get forPlatform => PlatformInfo.isDesktop ? compact : comfortable;

  /// The density from the nearest [SettingsDensityScope], else [forPlatform].
  static SettingsDensity of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsDensityScope>()?.density ?? forPlatform;

  /// Row title style: bodyLarge (comfortable) or bodyMedium with a tight line height (compact).
  TextStyle? titleStyle(BuildContext context) =>
      isCompact ? context.bodyMedium?.copyWith(height: 1.25) : context.bodyLarge;

  /// Supporting line style (bodySmall; a tight line height when compact).
  TextStyle? subtitleStyle(BuildContext context) =>
      isCompact ? context.bodySmall?.copyWith(height: 1.25) : context.bodySmall;
}

/// Overrides the platform's [SettingsDensity] below it (tests, previews).
class SettingsDensityScope extends InheritedWidget {
  final SettingsDensity density;
  const SettingsDensityScope({super.key, required this.density, required super.child});

  @override
  bool updateShouldNotify(SettingsDensityScope oldWidget) => density != oldWidget.density;
}

/// A labelled settings group: a sentence-case label, one card of rows and an optional footnote
/// under the card.
class SettingsSection extends StatelessWidget {
  final String label;
  final Widget child;

  /// Short explanatory text under the card (bodySmall, onSurfaceVariant).
  final String? footnote;

  /// Omit the label (the two-pane layout already names the section in its list).
  final bool showLabel;

  /// A widget under the card, after [footnote] (links and small text buttons).
  final Widget? footer;

  const SettingsSection({
    super.key,
    required this.label,
    required this.child,
    this.footnote,
    this.showLabel = true,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) SettingsSectionLabel(label),
          SettingsSectionCard(child: child),
          if (footnote != null) SettingsFootnote(footnote!),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// A section header in sentence case, as Material 3 list subheaders and current Apple HIG use.
/// Announced as a heading.
class SettingsSectionLabel extends StatelessWidget {
  final String title;
  const SettingsSectionLabel(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: context.labelLarge?.copyWith(color: context.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Short text under a card (bodySmall, onSurfaceVariant).
class SettingsFootnote extends StatelessWidget {
  final String text;
  const SettingsFootnote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Text(text, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
    );
  }
}

/// Draws a visible focus ring around [child] while it has keyboard focus ([focused]). The ring uses
/// the theme's secondary colour, 2px, so focus is never shown by a faint overlay alone.
class SettingsFocusRing extends StatelessWidget {
  final bool focused;
  final Widget child;
  final double radius;
  const SettingsFocusRing({super.key, required this.focused, required this.child, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: focused ? context.secondary : Colors.transparent, width: 2),
      ),
      child: child,
    );
  }
}

/// An [InkWell] for a settings row that paints [SettingsFocusRing] while it has keyboard focus.
class SettingsRowInk extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  const SettingsRowInk({super.key, required this.onTap, required this.child});

  @override
  State<SettingsRowInk> createState() => _SettingsRowInkState();
}

class _SettingsRowInkState extends State<SettingsRowInk> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return SettingsFocusRing(
      focused: _focused,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (value) => setState(() => _focused = value),
        borderRadius: BorderRadius.circular(10),
        child: widget.child,
      ),
    );
  }
}

/// How a [SettingsStatus] reads: fine, needs attention, blocked, or neutral (set elsewhere).
enum SettingsStatusKind { ok, warning, blocked, neutral }

/// A status shown with an icon and text, never by colour alone (WCAG 1.4.1): a check when fine,
/// a warning sign when it needs attention, a block sign when blocked, an outline when neutral.
class SettingsStatus extends StatelessWidget {
  final SettingsStatusKind kind;
  final String label;

  /// Key for the label's [Text] (tests read the label from it).
  final Key? textKey;
  final TextAlign textAlign;

  const SettingsStatus({super.key, required this.kind, required this.label, this.textKey, this.textAlign = TextAlign.start});

  static IconData iconFor(SettingsStatusKind kind) => switch (kind) {
        SettingsStatusKind.ok => Icons.check_circle_rounded,
        SettingsStatusKind.warning => Icons.warning_amber_rounded,
        SettingsStatusKind.blocked => Icons.block_rounded,
        SettingsStatusKind.neutral => Icons.remove_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      SettingsStatusKind.ok => context.secondary,
      SettingsStatusKind.warning || SettingsStatusKind.blocked => context.error,
      SettingsStatusKind.neutral => context.onSurfaceVariant,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconFor(kind),
            size: SettingsDensity.of(context).statusIconSize,
            color: color,
            key: ValueKey('settings-status-icon-${kind.name}')),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            key: textKey,
            textAlign: textAlign,
            style: context.labelLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// A [SettingsStatus] in a small rounded chip, for a row's title line. The chip never wraps its own
/// text: a row lays it out in a [Wrap], so it drops to the next line as a whole when it does not fit.
class SettingsStatusChip extends StatelessWidget {
  final SettingsStatusKind kind;
  final String label;
  final Key? textKey;
  const SettingsStatusChip({super.key, required this.kind, required this.label, this.textKey});

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      SettingsStatusKind.ok => context.secondary,
      SettingsStatusKind.warning || SettingsStatusKind.blocked => context.error,
      SettingsStatusKind.neutral => context.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: SettingsStatus(kind: kind, label: label, textKey: textKey),
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  final Widget child;
  const SettingsSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      child: child,
    );
  }
}

/// A short explanatory line inside a card.
class SettingsNote extends StatelessWidget {
  final String text;
  const SettingsNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SettingsDensity.of(context).horizontalPadding, vertical: 8),
      child: Text(text, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
    );
  }
}

/// Rows in a card are separated by a hairline inset to the title (past the icon).
class SettingsDivider extends StatelessWidget {
  /// Full width instead of inset (under a card header).
  final bool fullWidth;
  const SettingsDivider({super.key, this.fullWidth = false});

  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: fullWidth ? 0 : SettingsDensity.of(context).textInset, color: context.outlineVariant);
}

/// The one row layout of Settings: a plain icon, the [content] (title and an optional single
/// supporting line) and a trailing widget. Sizes follow [SettingsDensity]: comfortable rows are at
/// least 56dp tall with a supporting line and 48dp without; compact (desktop) rows 52 and 40px.
class SettingsRowLayout extends StatelessWidget {
  final IconData icon;
  final Widget content;
  final bool hasSubtitle;
  final Widget? trailing;

  /// Vertical padding; the density's when null.
  final double? verticalPadding;

  const SettingsRowLayout({
    super.key,
    required this.icon,
    required this.content,
    this.hasSubtitle = false,
    this.trailing,
    this.verticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final d = SettingsDensity.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: hasSubtitle ? d.rowHeightWithSubtitle : d.rowHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: d.horizontalPadding, vertical: verticalPadding ?? d.verticalPadding),
        child: Row(
          children: [
            Icon(icon, size: d.iconSize, color: context.onSurfaceVariant),
            SizedBox(width: d.iconGap),
            Expanded(child: content),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Title and an optional single supporting line.
class SettingsRowText extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? titleColor;
  const SettingsRowText({super.key, required this.title, this.subtitle, this.titleColor});

  @override
  Widget build(BuildContext context) {
    final d = SettingsDensity.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: d.titleStyle(context)?.copyWith(color: titleColor ?? context.onSurface)),
        if (subtitle != null) Text(subtitle!, style: d.subtitleStyle(context)?.copyWith(color: context.onSurfaceVariant)),
      ],
    );
  }
}

/// A row: leading icon, title, optional one-line supporting text, then a trailing value, status
/// or icon. Pass a chevron as [trailing] only when the row navigates or opens something. The row
/// is one semantics node (name, value, and the tap action when [onTap] is set).
class SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final IconData? trailing;
  final VoidCallback? onTap;

  /// Shows the version style ("v1.0") for [trailingText].
  final bool versionStyle;

  /// A destructive action: the title is in the error colour.
  final bool destructive;

  const SettingsActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.versionStyle = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: SettingsRowInk(
          onTap: onTap,
          child: SettingsRowLayout(
            icon: icon,
            hasSubtitle: subtitle != null,
            content: SettingsRowText(
              title: title,
              subtitle: subtitle,
              titleColor: destructive ? context.error : null,
            ),
            trailing: trailingText != null
                ? Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration:
                        BoxDecoration(color: context.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
                    child: Text(versionStyle ? 'v$trailingText' : trailingText!, style: context.monoMetadata),
                  )
                : trailing != null
                    ? Icon(trailing, size: SettingsDensity.of(context).trailingIconSize, color: context.onSurfaceVariant)
                    : null,
          ),
        ),
      ),
    );
  }
}

/// A row with an on/off switch. The whole row toggles.
class SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // One semantics node for the row: title, subtitle, switch state and the toggle action. The
    // whole row toggles and is the single keyboard stop (Space/Enter); the switch itself is not.
    return MergeSemantics(
      child: SettingsRowInk(
        onTap: () => onChanged(!value),
        child: SettingsRowLayout(
          icon: icon,
          hasSubtitle: subtitle != null,
          content: SettingsRowText(title: title, subtitle: subtitle),
          // Desktop: the switch without the padded 48px touch target (its 32px track is the target).
          trailing: ExcludeFocus(
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: SettingsDensity.of(context).isCompact ? MaterialTapTargetSize.shrinkWrap : null,
            ),
          ),
        ),
      ),
    );
  }
}
