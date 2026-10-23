import 'dart:io';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/theme_controller.dart';
import '../../home/presentation/home_controller.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/utilities/path_service.dart';
import '../../../core/presentation/widgets/show_dialog/confirm_dialog.dart';
import '../../recents/presentation/recents_controller.dart';

/// Settings screen (BRD 9.18, DESIGN_SPEC.md #01).
class SettingsController extends GetxController {
  final RecentRepository _recentRepository;
  final PathService _pathService;
  final AppSettingsRepository _settingsRepository;

  SettingsController({
    RecentRepository? recentRepository,
    PathService? pathService,
    AppSettingsRepository? settingsRepository,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _pathService = pathService ?? PathService.instance,
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl();

  ThemeController get themeController => Get.find<ThemeController>();

  final appVersion = ''.obs;

  /// Real cache size for the Cache card - never fabricated.
  final cacheSizeBytes = 0.obs;
  final isLoadingStats = true.obs;

  /// Default PDF reading mode (Reading Engine Preferences), persisted and
  /// applied by PdfReaderController on open.
  final defaultContinuousScroll = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadAppVersion();
    _loadStats();
    _loadReaderPreferences();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    appVersion.value = '${info.version} (${info.buildNumber})';
  }

  Future<void> _loadReaderPreferences() async {
    defaultContinuousScroll.value = await _settingsRepository.getDefaultContinuousScroll();
  }

  Future<void> setDefaultContinuousScroll(bool value) async {
    defaultContinuousScroll.value = value;
    await _settingsRepository.setDefaultContinuousScroll(value);
  }

  Future<void> _loadStats() async {
    isLoadingStats.value = true;

    final tempDirResult = await _pathService.getTempDirectory();
    await tempDirResult.fold(
      (_) async {},
      (directory) async {
        var size = 0;
        try {
          if (await directory.exists()) {
            await for (final entity in directory.list(recursive: true, followLinks: false)) {
              if (entity is! File) continue;
              try {
                size += await entity.length();
              } catch (_) {}
            }
          }
        } catch (_) {}
        cacheSizeBytes.value = size;
      },
    );
    isLoadingStats.value = false;
  }

  Future<void> clearRecentHistory() async {
    // Same confirmation as Library's Clear History (UX-16).
    final confirmed = await showConfirmDialog(
      title: 'Clear all reading history?',
      message: 'This will not delete your documents.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    final result = await _recentRepository.clearAll();
    result.fold(
      (failure) => CustomSnackbar.error(failure.message),
      (_) => CustomSnackbar.success('Recent history cleared.'),
    );
    // Settings is a pushed route, not a shell tab - popping back to Home
    // doesn't trigger any tab-select reload, so Home's own `recentDocuments`
    // list would otherwise keep showing the just-deleted history until the
    // app restarts.
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().load();
    }
    // Same for Library's History tab.
    if (Get.isRegistered<RecentsController>()) {
      await Get.find<RecentsController>().load();
    }
  }

  Future<void> clearCache() async {
    final result = await _pathService.getTempDirectory();
    await result.fold(
      (failure) async => CustomSnackbar.error(failure.message),
      (directory) async {
        try {
          if (await directory.exists()) {
            await for (final entity in directory.list()) {
              await entity.delete(recursive: true);
            }
          }
          CustomSnackbar.success('Cache cleared.');
          await _loadStats();
        } catch (e) {
          CustomSnackbar.error('Could not clear cache: $e');
        }
      },
    );
  }
}
