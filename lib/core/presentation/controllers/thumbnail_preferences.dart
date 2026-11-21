import 'package:get/get.dart';

import '../../data/repositories/app_settings_repository_impl.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// "Hide thumbnails in Recents" (ST-19): when on, document rows show the format icon instead of
/// the first-page preview. One reactive flag read by every row; Settings writes it, the app loads it
/// once at start.
class ThumbnailPreferences {
  ThumbnailPreferences._();

  static final hidden = false.obs;

  /// Reads the saved choice. An unreadable store leaves previews on.
  static Future<void> load([AppSettingsRepository? repository]) async {
    try {
      hidden.value = await (repository ?? AppSettingsRepositoryImpl()).getHideThumbnails();
    } catch (_) {}
  }
}
