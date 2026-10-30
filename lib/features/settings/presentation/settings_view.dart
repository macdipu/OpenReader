import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../services/platform_integration/default_app_service.dart';
import 'default_app_dialog.dart';
import 'settings_controller.dart';

/// Settings & Storage (DESIGN_SPEC.md #01): segmented appearance control,
/// the render cache and about. The PDF reading mode is chosen in the PDF
/// reader's toolbar, and reading history is cleared from Library's History.
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
          if (DefaultAppService.instance.isSupported) ...[
            const _SectionLabel('Default app'),
            _SectionCard(
              padding: const EdgeInsets.all(4),
              child: _ActionRow(
                icon: Icons.open_in_new_rounded,
                title: 'Make OpenReader your default reader',
                trailing: Icons.chevron_right_rounded,
                onTap: showDefaultAppDialog,
              ),
            ),
            const SizedBox(height: 24),
          ],
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
  final String? trailingText;
  final IconData? trailing;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: context.onSurfaceVariant, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: context.bodyLarge?.copyWith(color: context.onSurface))),
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
