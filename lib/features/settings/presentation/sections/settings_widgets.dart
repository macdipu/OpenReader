import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';

/// A labelled settings group.
class SettingsSection extends StatelessWidget {
  final String label;
  final Widget child;
  final bool padded;

  /// Omit the label (the two-pane layout already names the section in its list).
  final bool showLabel;

  const SettingsSection({
    super.key,
    required this.label,
    required this.child,
    this.padded = false,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) SettingsSectionLabel(label),
          SettingsSectionCard(padding: padded ? const EdgeInsets.all(12) : const EdgeInsets.all(4), child: child),
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
      padding: const EdgeInsets.only(left: 4, bottom: 6),
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
        Icon(iconFor(kind), size: 18, color: color, key: ValueKey('settings-status-icon-${kind.name}')),
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

/// Icon, title and optional supporting line over a control that is not a single trailing widget
/// (segmented choices, the text size stepper).
class SettingsBlockHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SettingsBlockHeader({super.key, required this.icon, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SettingsIconBadge(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.bodyLarge?.copyWith(color: context.onSurface)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SettingsSectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(4)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      child: child,
    );
  }
}

/// A short explanatory paragraph inside a card.
class SettingsNote extends StatelessWidget {
  final String text;
  const SettingsNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
    );
  }
}

/// Rows in a card are separated by a hairline.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(height: 1, color: context.outlineVariant);
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

  /// A status or current value shown before the trailing icon (e.g. "500 MB"). Null shows nothing.
  final String? status;

  /// Key for the [status] text.
  final Key? statusKey;

  /// Shows the version style ("v1.0") for [trailingText].
  final bool versionStyle;

  const SettingsActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.status,
    this.statusKey,
    this.versionStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: SettingsRowInk(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SettingsIconBadge(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.bodyLarge?.copyWith(color: context.onSurface)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            if (status != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(status!,
                      key: statusKey,
                      textAlign: TextAlign.end,
                      style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
                ),
              ),
            if (trailingText != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: context.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
                child: Text(versionStyle ? 'v$trailingText' : trailingText!, style: context.monoMetadata),
              ),
            if (trailing != null) Icon(trailing, color: context.onSurfaceVariant),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class SettingsIconBadge extends StatelessWidget {
  final IconData icon;
  const SettingsIconBadge(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: context.secondaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: context.secondary, size: 19),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SettingsIconBadge(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.bodyLarge?.copyWith(color: context.onSurface)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            ExcludeFocus(child: Switch(value: value, onChanged: onChanged)),
          ],
        ),
      ),
    ));
  }
}

/// One choice in a [SettingsSegmented].
class SettingsChoice<T> {
  final T value;
  final String label;
  final IconData? icon;
  const SettingsChoice(this.value, this.label, {this.icon});
}

/// Equal-width choice tiles for two or three options (Light / Dark / System, ...).
class SettingsSegmented<T> extends StatelessWidget {
  final T value;
  final List<SettingsChoice<T>> choices;
  final ValueChanged<T> onChanged;

  const SettingsSegmented({super.key, required this.value, required this.choices, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final choice in choices)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                button: true,
                selected: value == choice.value,
                child: SettingsRowInk(
                  onTap: () => onChanged(choice.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    // At least 48dp tall, also without an icon.
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(vertical: choice.icon == null ? 14 : 12, horizontal: 2),
                    decoration: BoxDecoration(
                      color: value == choice.value ? context.surfaceContainerLowest : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: value == choice.value ? context.secondary : context.outlineVariant,
                        width: value == choice.value ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (choice.icon != null) ...[
                          Icon(choice.icon, size: 20, color: value == choice.value ? context.secondary : context.onSurfaceVariant),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          choice.label,
                          textAlign: TextAlign.center,
                          style: context.labelMedium?.copyWith(
                            color: value == choice.value ? context.secondary : context.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
