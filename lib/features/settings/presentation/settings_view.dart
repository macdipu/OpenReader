import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import 'settings_controller.dart';

/// Settings & Storage (DESIGN_SPEC.md #01): privacy banner, segmented
/// appearance control, reading preferences, storage bento grid, privacy
/// statement, about.
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ContentConstraint(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _SectionLabel('Appearance'),
          _SectionCard(
            padding: const EdgeInsets.all(12),
            child: Obx(() => _ThemeSegmented(
                  mode: controller.themeController.themeMode,
                  onChanged: (mode) {
                    switch (mode) {
                      case ThemeMode.system:
                        controller.themeController.setSystemTheme();
                        break;
                      case ThemeMode.light:
                        controller.themeController.setLightTheme();
                        break;
                      case ThemeMode.dark:
                        controller.themeController.setDarkTheme();
                        break;
                    }
                  },
                )),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Reading Engine Preferences'),
          _SectionCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Default PDF Reader Mode', style: context.labelMedium?.copyWith(color: context.onSurfaceVariant)),
                ),
                const SizedBox(height: 8),
                Obx(() => Row(
                      children: [
                        Expanded(
                          child: _ModeTile(
                            icon: Icons.view_agenda_outlined,
                            label: 'Continuous Scroll',
                            selected: controller.defaultContinuousScroll.value,
                            onTap: () => controller.setDefaultContinuousScroll(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeTile(
                            icon: Icons.auto_stories_outlined,
                            label: 'Page by Page',
                            selected: !controller.defaultContinuousScroll.value,
                            onTap: () => controller.setDefaultContinuousScroll(false),
                          ),
                        ),
                      ],
                    )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Applies the next time you open a PDF',
                    style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // No storage scan any more (CR-OPENREADER-BROWSE), so no index
          // count or Rescan here - just the render cache.
          const _SectionLabel('Cache'),
          Obx(() => _StatBento(
                icon: Icons.cleaning_services_outlined,
                value: controller.isLoadingStats.value ? '—' : formatFileSize(controller.cacheSizeBytes.value),
                label: 'cached render tiles',
                actionLabel: 'Clear Render Cache',
                destructive: true,
                onAction: controller.clearCache,
              )),
          const SizedBox(height: 12),
          _SectionCard(
            padding: const EdgeInsets.all(4),
            child: _ActionRow(
              icon: Icons.history_toggle_off_outlined,
              title: 'Clear Recent History',
              subtitle: 'Removes reading history, keeps your files',
              destructive: true,
              onTap: controller.clearRecentHistory,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          _SectionCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                Obx(() => _ActionRow(
                      icon: Icons.info_outline,
                      title: 'Version',
                      trailingText: controller.appVersion.value,
                    )),
                Divider(height: 1, color: context.outlineVariant),
                _ActionRow(
                  icon: Icons.description_outlined,
                  title: 'Open-source licenses',
                  trailing: Icons.chevron_right_rounded,
                  onTap: () => showLicensePage(context: context, applicationName: 'OpenReader'),
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }
}

class _ThemeSegmented extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSegmented({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [
      (mode: ThemeMode.light, label: 'Light', icon: Icons.light_mode_outlined),
      (mode: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_outlined),
      (mode: ThemeMode.system, label: 'System', icon: Icons.brightness_auto_outlined),
    ];
    return Row(
      children: [
        for (final option in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(button: true, selected: mode == option.mode, child: InkWell(
                onTap: () => onChanged(option.mode),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: mode == option.mode ? context.surfaceContainerLowest : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: mode == option.mode ? context.secondary : context.outlineVariant,
                      width: mode == option.mode ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(option.icon, size: 20, color: mode == option.mode ? context.secondary : context.onSurfaceVariant),
                      const SizedBox(height: 4),
                      Text(
                        option.label,
                        style: context.labelMedium?.copyWith(
                          color: mode == option.mode ? context.secondary : context.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ),
          ),
      ],
    );
  }
}

/// 2-tile selector for Reading Engine Preferences (DESIGN_SPEC #01).
class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, selected: selected, child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? context.secondaryContainer : context.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? context.secondary : context.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: selected ? context.secondary : context.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.labelMedium?.copyWith(color: selected ? context.secondary : context.onSurface),
            ),
          ],
        ),
      ),
    ));
  }
}

/// Bento-style stat card for Storage & Cache Manager (DESIGN_SPEC #01):
/// icon + big number + action button, real data only.
class _StatBento extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool destructive;

  const _StatBento({
    required this.icon,
    required this.value,
    required this.label,
    required this.actionLabel,
    required this.onAction,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.onSurfaceVariant, size: 20),
          const SizedBox(height: 10),
          Text(value, style: context.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: destructive ? context.error : context.secondary,
                side: BorderSide(color: destructive ? context.error : context.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                actionLabel,
                style: context.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: context.labelLarge?.copyWith(color: context.onSurfaceVariant, letterSpacing: 1),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _SectionCard({required this.child, this.padding = const EdgeInsets.all(4)});

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

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final IconData? trailing;
  final bool destructive;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.destructive = false,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.error : context.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.secondary),
                  )
                : Icon(icon, color: destructive ? context.error : context.onSurfaceVariant, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.bodyLarge?.copyWith(color: color)),
                  if (subtitle != null)
                    Text(subtitle!, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailingText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('v${trailingText!}', style: context.monoMetadata),
              ),
            if (trailing != null) Icon(trailing, color: context.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
