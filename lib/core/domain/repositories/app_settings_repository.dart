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

  /// Whether the one-time automatic first-run scan (BRD 7.1) has already
  /// run, so Home doesn't re-trigger it every time the index is legitimately
  /// empty (e.g. after the user clears it).
  Future<bool> hasAutoScanned();

  /// Mark the automatic first-run scan as done.
  Future<void> setAutoScanned(bool value);

  /// Default PDF reading mode (BRD 9.10, Settings "Reading Engine
  /// Preferences") applied when a reader opens, until changed in-session.
  Future<bool> getDefaultContinuousScroll();

  /// Persist the default PDF reading mode.
  Future<void> setDefaultContinuousScroll(bool value);

  /// Text reader font size (UX-20), shared by every text file; null when
  /// never set.
  Future<double?> getTextReaderFontSize();

  Future<void> setTextReaderFontSize(double value);

  /// Text reader line wrap (UX-20); null when never set.
  Future<bool?> getTextReaderLineWrap();

  Future<void> setTextReaderLineWrap(bool value);

  /// Night mode, shared by every reader (UX-33); null when never set.
  Future<bool?> getReaderNightMode();

  Future<void> setReaderNightMode(bool value);

  /// Clear all app settings
  Future<void> clearSettings();
}

