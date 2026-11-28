import '../models/keep_state.dart';
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

  /// Reopen a document where the reader left off (ST-05); default true.
  /// When off, readers do not apply the stored position and do not overwrite it until the user
  /// has moved. Positions are only recorded while history is on (retention is not "Off").
  Future<bool> getRestoreReadingPosition();

  Future<void> setRestoreReadingPosition(bool value);

  /// Cap on cached temp files in MB (ST-12); null means no cap.
  Future<int?> getCacheCapMb();

  /// Pass null to remove the cap.
  Future<void> setCacheCapMb(int? value);

  /// Days to keep reading history (ST-11); null means forever, 0 means
  /// record nothing.
  Future<int?> getHistoryRetentionDays();

  /// Pass null to keep history forever.
  Future<void> setHistoryRetentionDays(int? value);

  /// Show the format icon instead of the first-page preview in document rows (ST-19);
  /// default false.
  Future<bool> getHideThumbnails();

  Future<void> setHideThumbnails(bool value);

  /// Keep the screen awake while a reader is visible (ST-16); default false.
  Future<bool> getKeepScreenAwake();

  Future<void> setKeepScreenAwake(bool value);

  /// Build the theme's accent colours from the system's dynamic palette (Material You wallpaper
  /// colours on Android 12+, the accent colour on desktop) (ST-20); default false.
  Future<bool> getUseDynamicColor();

  Future<void> setUseDynamicColor(bool value);

  /// What to do with a copy of a file another app shared when its reader is closed (Android);
  /// default [SharedCopyAction.ask].
  Future<SharedCopyAction> getSharedCopyAction();

  Future<void> setSharedCopyAction(SharedCopyAction value);

  /// Clear all app settings
  Future<void> clearSettings();

  /// Clear every preference except the onboarding and first-scan flags, which are never missing
  /// along the way: a reset must not send the user back through onboarding or rescan storage.
  Future<void> clearPreferencesKeepingSetup();
}

