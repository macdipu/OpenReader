import 'package:openreader/core/domain/models/theme_mode_enum.dart';
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// None of these values are sensitive (theme choice, locale, an onboarding
/// flag), so this reads/writes plain SharedPreferences directly rather than
/// going through the Keystore-backed `SharedPreference` cache wrapper
/// (lib/core/data/cache/preference/shared_preference.dart, despite its name,
/// wraps FlutterSecureStorage). That wrapper's Android-Keystore cipher
/// migration was verified to hang the app's cold-start bootstrap indefinitely
/// on a real emulator (see FEATURE-OPENREADER-P5/tasks/TASK-013.md) — routing
/// non-sensitive settings around it removes that hang from the splash path.
class AppSettingsRepositoryImpl implements AppSettingsRepository {
  static const String _themeKey = 'app_settings:theme_mode';
  static const String _localeKey = 'app_settings:locale';
  static const String _onboardingCompleteKey = 'app_settings:onboarding_complete';
  static const String _autoScannedKey = 'app_settings:auto_scanned';
  static const String _defaultContinuousScrollKey = 'app_settings:default_continuous_scroll';
  static const String _textReaderFontSizeKey = 'app_settings:text_reader_font_size';
  static const String _textReaderLineWrapKey = 'app_settings:text_reader_line_wrap';
  static const String _pdfNightModeKey = 'app_settings:pdf_night_mode';

  @override
  Future<AppThemeMode> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeKey);
      if (value == null) {
        return AppThemeMode.system;
      }
      return AppThemeMode.fromString(value);
    } catch (e) {
      return AppThemeMode.system;
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toStringValue());
  }

  @override
  Future<String?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey);
  }

  @override
  Future<void> setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
  }

  @override
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  @override
  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, value);
  }

  @override
  Future<bool> hasAutoScanned() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoScannedKey) ?? false;
  }

  @override
  Future<void> setAutoScanned(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoScannedKey, value);
  }

  @override
  Future<double?> getTextReaderFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_textReaderFontSizeKey);
  }

  @override
  Future<void> setTextReaderFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textReaderFontSizeKey, value);
  }

  @override
  Future<bool?> getTextReaderLineWrap() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_textReaderLineWrapKey);
  }

  @override
  Future<void> setTextReaderLineWrap(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_textReaderLineWrapKey, value);
  }

  @override
  Future<bool?> getPdfNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pdfNightModeKey);
  }

  @override
  Future<void> setPdfNightMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pdfNightModeKey, value);
  }

  @override
  Future<bool> getDefaultContinuousScroll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_defaultContinuousScrollKey) ?? true;
  }

  @override
  Future<void> setDefaultContinuousScroll(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_defaultContinuousScrollKey, value);
  }

  @override
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    await prefs.remove(_localeKey);
    await prefs.remove(_onboardingCompleteKey);
    await prefs.remove(_autoScannedKey);
    await prefs.remove(_defaultContinuousScrollKey);
    await prefs.remove(_textReaderFontSizeKey);
    await prefs.remove(_textReaderLineWrapKey);
    await prefs.remove(_pdfNightModeKey);
  }
}

