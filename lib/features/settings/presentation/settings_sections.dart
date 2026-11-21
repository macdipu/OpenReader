import 'package:flutter/material.dart';

import '../../../core/presentation/utils/platform_info.dart';
import 'sections/about_section.dart';
import 'sections/appearance_section.dart';
import 'sections/file_handling_section.dart';
import 'sections/open_with_section.dart';
import 'sections/permissions_section.dart';
import 'sections/privacy_section.dart';
import 'sections/reading_section.dart';
import 'sections/shortcuts_section.dart';
import 'sections/data_section.dart';
import 'settings_controller.dart';

/// The sections of Settings (CR-SETTINGS-UX "Section order").
enum SettingsSectionId {
  permissions('Permissions', Icons.verified_user_outlined),
  fileHandling('File handling', Icons.menu_book_rounded),
  reading('Reading', Icons.chrome_reader_mode_outlined),
  appearance('Appearance', Icons.palette_outlined),
  data('Data', Icons.storage_rounded),
  privacy('Privacy', Icons.shield_outlined),
  openWith('Open with', Icons.open_in_new_rounded),
  shortcuts('Keyboard shortcuts', Icons.keyboard_outlined),
  about('Help & about', Icons.help_outline_rounded);

  final String title;
  final IconData icon;
  const SettingsSectionId(this.title, this.icon);

  Widget build(SettingsController controller, {required bool showLabel}) => switch (this) {
        permissions => PermissionsSection(controller: controller, showLabel: showLabel),
        fileHandling => FileHandlingSection(controller: controller, showLabel: showLabel),
        reading => ReadingSection(controller: controller, showLabel: showLabel),
        appearance => AppearanceSection(controller: controller, showLabel: showLabel),
        data => DataSection(controller: controller, showLabel: showLabel),
        privacy => PrivacySection(controller: controller, showLabel: showLabel),
        openWith => OpenWithSection(showLabel: showLabel),
        shortcuts => ShortcutsSection(showLabel: showLabel),
        about => AboutSection(controller: controller, showLabel: showLabel),
      };
}

/// The sections this platform shows, in its order. Phones and tablets: Permissions first and the
/// Open-with tip; desktop (including macOS): File handling first and the shortcuts. The order
/// follows the platform, the layout (single column or two panes) follows the window width.
List<SettingsSectionId> settingsSectionsForPlatform() {
  if (PlatformInfo.isDesktop) {
    return const [
      SettingsSectionId.fileHandling,
      SettingsSectionId.reading,
      SettingsSectionId.appearance,
      SettingsSectionId.data,
      SettingsSectionId.privacy,
      SettingsSectionId.shortcuts,
      SettingsSectionId.about,
    ];
  }
  return const [
    SettingsSectionId.permissions,
    SettingsSectionId.reading,
    SettingsSectionId.appearance,
    SettingsSectionId.data,
    SettingsSectionId.privacy,
    SettingsSectionId.openWith,
    SettingsSectionId.about,
  ];
}
