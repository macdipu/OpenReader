import 'dart:io';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/presentation/controllers/theme_controller.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/utilities/path_service.dart';

/// Settings screen (BRD 9.18, DESIGN_SPEC.md #01).
class SettingsController extends GetxController {
  final PathService _pathService;

  SettingsController({PathService? pathService}) : _pathService = pathService ?? PathService.instance;

  ThemeController get themeController => Get.find<ThemeController>();

  final appVersion = ''.obs;

  /// Real cache size for the Cache card - never fabricated.
  final cacheSizeBytes = 0.obs;
  final isLoadingStats = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadAppVersion();
    _loadStats();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    appVersion.value = '${info.version} (${info.buildNumber})';
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
