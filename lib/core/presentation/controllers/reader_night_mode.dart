import 'dart:async';

import 'package:get/get.dart';

import '../../data/repositories/app_settings_repository_impl.dart';
import '../../domain/repositories/app_settings_repository.dart';
import 'reader_preferences.dart';

/// Night mode for a reader (UX-33): one choice shared by every reader and
/// remembered across launches. [ReaderNightModeView] draws it.
mixin ReaderNightMode on GetxController {
  final nightMode = false.obs;

  /// Where the choice is kept; readers with their own repository use it.
  AppSettingsRepository get readerSettings => _defaultSettings;
  late final AppSettingsRepository _defaultSettings = AppSettingsRepositoryImpl();

  @override
  void onInit() {
    super.onInit();
    _loadNightMode();
    // Settings (or another open reader) changed it: follow (live sync).
    _nightModeSync = ReaderPreferences.changes.listen((change) {
      if (change.preference == ReaderPreference.nightMode && change.value is bool) {
        nightMode.value = change.value as bool;
      }
    });
  }

  StreamSubscription<ReaderPreferenceChange>? _nightModeSync;

  @override
  void onClose() {
    unawaited(_nightModeSync?.cancel());
    super.onClose();
  }

  Future<void> _loadNightMode() async {
    try {
      nightMode.value = await readerSettings.getReaderNightMode() ?? false;
    } catch (_) {
      // A preference, not a requirement - the reader works without it.
    }
  }

  void toggleNightMode() {
    nightMode.value = !nightMode.value;
    ReaderPreferences.publish(ReaderPreference.nightMode, nightMode.value);
    try {
      unawaited(readerSettings.setReaderNightMode(nightMode.value).catchError((_) {}));
    } catch (_) {}
  }
}
