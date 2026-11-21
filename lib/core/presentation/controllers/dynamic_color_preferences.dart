import 'package:dynamic_color/dynamic_color.dart' show DynamicColorPlugin;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/app_settings_repository_impl.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// A light and a dark colour scheme built from the system's dynamic palette.
typedef DynamicSchemes = ({ColorScheme light, ColorScheme dark});

/// "Use wallpaper colours" (ST-20, Material You): when on and the system offers a dynamic palette,
/// the app theme takes its accent colours from it (see `AppTheme.light`/`AppTheme.dark`).
///
/// [light] and [dark] hold the system palette, or null where there is none (iOS, Android before
/// 12, a desktop that reports no accent colour); Settings then hides the switch. Settings writes
/// [enabled]; the app loads both once at start and rebuilds its theme when either changes.
class DynamicColorPreferences {
  DynamicColorPreferences._();

  static final enabled = false.obs;
  static final light = Rxn<ColorScheme>();
  static final dark = Rxn<ColorScheme>();

  /// Whether the system offers a dynamic palette.
  static bool get available => light.value != null && dark.value != null;

  /// The schemes the theme should use, or null for the app's own colours.
  static ColorScheme? get activeLight => enabled.value ? light.value : null;
  static ColorScheme? get activeDark => enabled.value ? dark.value : null;

  /// Reads the saved choice and asks the platform for its palette ([source], for tests). Either
  /// failing leaves the app's own colours.
  static Future<void> load({AppSettingsRepository? repository, Future<DynamicSchemes?> Function()? source}) async {
    try {
      enabled.value = await (repository ?? AppSettingsRepositoryImpl()).getUseDynamicColor();
    } catch (_) {}
    try {
      final schemes = await (source ?? readPlatform)();
      light.value = schemes?.light;
      dark.value = schemes?.dark;
    } catch (_) {
      light.value = null;
      dark.value = null;
    }
  }

  /// Android 12+ wallpaper palette, else the desktop accent colour (macOS, Windows, GTK Linux),
  /// else null. `dynamic_color` builds its schemes with `material_ui`'s ColorScheme, not the one
  /// this app's `ThemeData` takes, so only its raw palette values are used here.
  static Future<DynamicSchemes?> readPlatform() async {
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (palette != null) return fromPrimaryTones(palette.primary.get);
    } catch (_) {}
    try {
      final accent = await DynamicColorPlugin.getAccentColor();
      if (accent != null) return fromSeed(accent);
    } catch (_) {}
    return null;
  }

  /// Schemes from a palette's primary tonal palette ([tone] gives the ARGB colour at a tone),
  /// with the Material 3 tones Android uses for the primary roles.
  static DynamicSchemes fromPrimaryTones(int Function(int tone) tone) {
    ColorScheme build(Brightness brightness) {
      final isDark = brightness == Brightness.dark;
      return ColorScheme.fromSeed(seedColor: Color(tone(40)), brightness: brightness).copyWith(
        primary: Color(tone(isDark ? 80 : 40)),
        onPrimary: Color(tone(isDark ? 20 : 100)),
        primaryContainer: Color(tone(isDark ? 30 : 90)),
        onPrimaryContainer: Color(tone(isDark ? 90 : 10)),
        inversePrimary: Color(tone(isDark ? 40 : 80)),
      );
    }

    return (light: build(Brightness.light), dark: build(Brightness.dark));
  }

  /// Schemes seeded from a single accent colour.
  static DynamicSchemes fromSeed(Color seed) => (
        light: ColorScheme.fromSeed(seedColor: seed),
        dark: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      );
}
