import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/theme/theme_extensions.dart';
import 'settings_controller.dart';

/// Settings & Storage (DESIGN_SPEC.md #01): privacy banner, segmented
/// appearance control, storage actions, privacy statement, about.
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
          const SizedBox(height: 20),
          const _SectionLabel('Appearance'),
          _SectionCard(
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
          const SizedBox(height: 20),
          const _SectionLabel('Storage & Cache'),
          _SectionCard(
            child: Column(
              children: [
                Obx(() => _ActionRow(
                      icon: Icons.refresh_rounded,
                      title: 'Rescan Local Storage',
                      subtitle: 'Re-index documents found on this device',
                      busy: controller.isRefreshingIndex.value,
                      onTap: controller.isRefreshingIndex.value ? null : controller.refreshFileIndex,
                    )),
                Divider(height: 1, color: context.outlineVariant),
                _ActionRow(
                  icon: Icons.history_toggle_off_outlined,
                  title: 'Clear Recent History',
                  subtitle: 'Removes reading history, keeps your files',
                  onTap: controller.clearRecentHistory,
                ),
                Divider(height: 1, color: context.outlineVariant),
                _ActionRow(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear Render Cache',
                  subtitle: 'Frees temporary preview/render files',
                  destructive: true,
                  onTap: controller.clearCache,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Privacy & System Integrity'),
          _SectionCard(
            child: Column(
              children: [
                const _InfoRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Local-only processing',
                  subtitle: 'Your documents, filenames, and search terms never leave this device. '
                      'OpenReader has no server and no analytics.',
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
          const SizedBox(height: 20),
          const _SectionLabel('About'),
          _SectionCard(
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
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
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
