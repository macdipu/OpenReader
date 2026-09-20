import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined, size: 12, color: context.secondary),
                const SizedBox(width: 4),
                Text('SANDBOXED', style: context.monoMetadata),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _PrivacyBanner(),
          const SizedBox(height: 24),
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
          const _SectionLabel('Storage & Cache'),
          Obx(() => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatBento(
                      icon: Icons.description_outlined,
                      value: controller.isLoadingStats.value ? '—' : '${controller.indexedDocumentCount.value}',
                      label: 'indexed documents',
                      busy: controller.isRefreshingIndex.value,
                      busyLabel: controller.isRefreshingIndex.value ? 'Found ${controller.scanProgress.value}…' : null,
                      actionLabel: 'Rescan Local Storage',
                      onAction: controller.isRefreshingIndex.value ? null : controller.refreshFileIndex,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBento(
                      icon: Icons.cleaning_services_outlined,
                      value: controller.isLoadingStats.value ? '—' : formatFileSize(controller.cacheSizeBytes.value),
                      label: 'cached render tiles',
                      actionLabel: 'Clear Render Cache',
                      destructive: true,
                      onAction: controller.clearCache,
                    ),
                  ),
                ],
              )),
          const SizedBox(height: 12),
          _SectionCard(
            padding: const EdgeInsets.all(4),
            child: _ActionRow(
              icon: Icons.history_toggle_off_outlined,
              title: 'Clear Recent History',
              subtitle: 'Removes reading history, keeps your files',
              onTap: controller.clearRecentHistory,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Privacy & System Integrity'),
          _SectionCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                const _InfoRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Local-only processing',
                  subtitle: 'Your documents, filenames, and search terms never leave this device. '
                      'OpenReader has no server and no analytics.',
                ),
                Divider(height: 1, color: context.outlineVariant),
                const _InfoRow(
                  icon: Icons.shield_outlined,
                  title: 'Scoped storage sandbox',
                  subtitle: 'Access is limited to what Android granted - your own folder plus '
                      'any folder you explicitly picked. No broader filesystem access.',
                ),
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
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          _SectionCard(
            padding: const EdgeInsets.all(4),
            child: Obx(() => _ActionRow(
                  icon: Icons.info_outline,
                  title: 'Version',
                  trailingText: controller.appVersion.value,
                )),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tertiaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.tertiary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.shield_outlined, color: context.tertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('100% Offline', style: context.titleSmall),
                Text(
                  'No cloud sync, no telemetry, no accounts.',
                  style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
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
      (mode: ThemeMode.system, label: 'System', icon: Icons.smartphone_outlined),
    ];
    return Row(
      children: [
        for (final option in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
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
              ),
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
    return InkWell(
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
    );
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
  final bool busy;
  final String? busyLabel;

  const _StatBento({
    required this.icon,
    required this.value,
    required this.label,
    required this.actionLabel,
    required this.onAction,
    this.destructive = false,
    this.busy = false,
    this.busyLabel,
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
          Text(busy && busyLabel != null ? '…' : value, style: context.headlineSmall),
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
              child: busy
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.secondary),
                    )
                  : Text(
                      busyLabel ?? actionLabel,
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.onSurfaceVariant, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.bodyLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
