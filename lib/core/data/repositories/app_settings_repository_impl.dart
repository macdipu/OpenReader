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
  // Named for the PDF reader, which had night mode first; kept so the
  // choice made there carries over to every reader.
  static const String _readerNightModeKey = 'app_settings:pdf_night_mode';

  static const String _restoreReadingPositionKey = 'app_settings:restore_reading_position';
  static const String _cacheCapMbKey = 'app_settings:cache_cap_mb';
  static const String _historyRetentionDaysKey = 'app_settings:history_retention_days';
  static const String _hideThumbnailsKey = 'app_settings:hide_thumbnails';

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
  Future<bool?> getReaderNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_readerNightModeKey);
  }

  @override
  Future<void> setReaderNightMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_readerNightModeKey, value);
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

  Future<int?> _getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  Future<void> _setNullableInt(String key, int? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, value);
    }
  }

  Future<bool> _getBool(String key, bool fallback) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? fallback;
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Future<bool> getRestoreReadingPosition() async {
    // Read on every document open; an unreadable store must not stop the
    // reader, so it falls back to the default.
    try {
      return await _getBool(_restoreReadingPositionKey, true);
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setRestoreReadingPosition(bool value) => _setBool(_restoreReadingPositionKey, value);

  @override
  Future<int?> getCacheCapMb() => _getInt(_cacheCapMbKey);

  @override
  Future<void> setCacheCapMb(int? value) => _setNullableInt(_cacheCapMbKey, value);

  @override
  Future<int?> getHistoryRetentionDays() => _getInt(_historyRetentionDaysKey);

  @override
  Future<void> setHistoryRetentionDays(int? value) => _setNullableInt(_historyRetentionDaysKey, value);

  @override
  Future<bool> getHideThumbnails() async {
    try {
      return await _getBool(_hideThumbnailsKey, false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setHideThumbnails(bool value) => _setBool(_hideThumbnailsKey, value);

  @override
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await clearPreferencesKeepingSetup();
    await prefs.remove(_onboardingCompleteKey);
    await prefs.remove(_autoScannedKey);
  }

  @override
  Future<void> clearPreferencesKeepingSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    await prefs.remove(_localeKey);
    await prefs.remove(_defaultContinuousScrollKey);
    await prefs.remove(_textReaderFontSizeKey);
    await prefs.remove(_textReaderLineWrapKey);
    await prefs.remove(_readerNightModeKey);
    await prefs.remove(_restoreReadingPositionKey);
    await prefs.remove(_cacheCapMbKey);
    await prefs.remove(_historyRetentionDaysKey);
    await prefs.remove(_hideThumbnailsKey);
  }
}
