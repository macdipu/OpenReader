import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/platform_info.dart';
import '../../../services/platform_integration/default_app_service.dart';
import 'default_app_dialog.dart';
import 'settings_controller.dart';

/// Settings & Storage (DESIGN_SPEC.md #01): segmented appearance control,
/// the default-app prompt, the render cache and about. The PDF reading mode
/// is chosen in the PDF reader's toolbar, and reading history is cleared from
/// Library's History. Wide windows (desktop, tablets) lay the cards out in two
/// columns under a page header.
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = context.screenDimensions.width >= 900;

    final appearance = _Section(
      label: 'Appearance',
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
      padded: true,
    );

    final defaultApp = DefaultAppService.instance.isSupported
        ? _Section(
            label: 'Default app',
            child: _ActionRow(
              icon: Icons.menu_book_rounded,
              title: 'Make OpenReader your default reader',
              subtitle: PlatformInfo.isAndroid
                  ? 'Open PDFs, Word, Excel and more here by default'
                  : 'For every document type, or just the ones you pick (like PDFs)',
              trailing: Icons.chevron_right_rounded,
              onTap: showDefaultAppDialog,
            ),
          )
        : null;

    // No storage scan any more (CR-OPENREADER-BROWSE), so no index count or
    // Rescan here - just the render cache.
    final cache = _Section(
      label: 'Cache',
      child: Obx(() => _StatBento(
            icon: Icons.cleaning_services_outlined,
            value: controller.isLoadingStats.value ? '—' : formatFileSize(controller.cacheSizeBytes.value),
            label: 'cached render tiles',
            actionLabel: 'Clear Render Cache',
            destructive: true,
            onAction: controller.clearCache,
          )),
      bare: true,
    );

    final about = _Section(
      label: 'About',
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
    );

    final left = [appearance, if (defaultApp != null) defaultApp];
    final right = [cache, about];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ContentConstraint(
        maxWidth: wide ? 1040 : ScreenUtils.maxContentWidth,
        child: ListView(
          padding: EdgeInsets.fromLTRB(wide ? 32 : 16, wide ? 28 : 16, wide ? 32 : 16, 32),
          children: [
            if (wide) ...[
              Text('Settings', style: context.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Appearance, defaults and storage', style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  const SizedBox(width: 24),
                  Expanded(child: Column(children: right)),
                ],
              ),
            ] else
              ...[...left, ...right],
          ],
        ),
      ),
    );
  }
}

/// A labelled settings group.
class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  final bool padded;
  final bool bare;

  const _Section({required this.label, required this.child, this.padded = false, this.bare = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label),
          if (bare) child else _SectionCard(padding: padded ? const EdgeInsets.all(12) : const EdgeInsets.all(4), child: child),
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
  final String? subtitle;
  final String? trailingText;
  final IconData? trailing;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: context.secondaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: context.secondary, size: 19),
            ),
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
