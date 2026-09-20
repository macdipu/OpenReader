import 'dart:io';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/theme_controller.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/utilities/path_service.dart';

/// Settings screen (BRD 9.18, DESIGN_SPEC.md #01).
class SettingsController extends GetxController {
  final DocumentRepository _documentRepository;
  final RecentRepository _recentRepository;
  final PathService _pathService;
  final AppSettingsRepository _settingsRepository;

  SettingsController({
    DocumentRepository? documentRepository,
    RecentRepository? recentRepository,
    PathService? pathService,
    AppSettingsRepository? settingsRepository,
  })  : _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _pathService = pathService ?? PathService.instance,
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl();

  ThemeController get themeController => Get.find<ThemeController>();

  final isRefreshingIndex = false.obs;
  final scanProgress = 0.obs;
  final appVersion = ''.obs;

  /// Real stats for the Storage & Cache bento grid - never fabricated.
  final indexedDocumentCount = 0.obs;
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
    var total = 0;
    for (final category in DocumentCategory.values.where((c) => c != DocumentCategory.unknown)) {
      final result = await _documentRepository.countByCategory(category);
      result.fold((_) {}, (count) => total += count);
    }
    indexedDocumentCount.value = total;

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

  Future<void> refreshFileIndex() async {
    isRefreshingIndex.value = true;
    scanProgress.value = 0;
    final result = await _documentRepository.rescan(onProgress: (count) => scanProgress.value = count);
    isRefreshingIndex.value = false;
    result.fold(
      (failure) => CustomSnackbar.error(failure.message),
      (documents) => CustomSnackbar.success('Found ${documents.length} document(s).'),
    );
    await _loadStats();
  }

  Future<void> clearRecentHistory() async {
    final result = await _recentRepository.clearAll();
    result.fold(
      (failure) => CustomSnackbar.error(failure.message),
      (_) => CustomSnackbar.success('Recent history cleared.'),
    );
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
