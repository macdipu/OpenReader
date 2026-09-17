import '../models/theme_mode_enum.dart';

abstract class AppSettingsRepository {
  /// Get the current theme mode
  Future<AppThemeMode> getThemeMode();

  /// Save theme mode preference
  Future<void> setThemeMode(AppThemeMode mode);

  /// Get locale preference
  Future<String?> getLocale();

  /// Save locale preference
  Future<void> setLocale(String locale);

  /// Whether the storage-access onboarding flow (BRD 9.2) has been completed.
  Future<bool> hasCompletedOnboarding();

  /// Mark the storage-access onboarding flow as completed.
  Future<void> setOnboardingComplete(bool value);

  /// Clear all app settings
  Future<void> clearSettings();
}

