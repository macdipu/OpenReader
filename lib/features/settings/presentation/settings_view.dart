import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/theme/theme_extensions.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          Obx(() => RadioGroup<ThemeMode>(
                groupValue: controller.themeController.themeMode,
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
                    case null:
                      break;
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(title: Text('System'), value: ThemeMode.system),
                    RadioListTile<ThemeMode>(title: Text('Light'), value: ThemeMode.light),
                    RadioListTile<ThemeMode>(title: Text('Dark'), value: ThemeMode.dark),
                  ],
                ),
              )),
          const Divider(),
          const _SectionHeader('Files'),
          Obx(() => ListTile(
                leading: controller.isRefreshingIndex.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                title: const Text('Refresh file index'),
                onTap: controller.isRefreshingIndex.value ? null : controller.refreshFileIndex,
              )),
          ListTile(
            leading: const Icon(Icons.history_toggle_off_outlined),
            title: const Text('Clear Recent history'),
            onTap: controller.clearRecentHistory,
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear cache'),
            onTap: controller.clearCache,
          ),
          const Divider(),
          const _SectionHeader('Privacy'),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Local-only processing'),
            subtitle: Text(
              'Your documents, filenames, and search terms never leave this device. '
              'OpenDocs has no server and no analytics.',
            ),
          ),
          const Divider(),
          const _SectionHeader('About'),
          Obx(() => ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                subtitle: Text(controller.appVersion.value),
              )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: context.labelLarge?.copyWith(color: context.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
