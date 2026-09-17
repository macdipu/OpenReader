import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/theme_controller.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/utilities/path_service.dart';

/// Settings screen (BRD 9.18). Reader preferences aren't listed here yet -
/// they apply to reader screens that ship in BRD Phase 2/3, not this
/// Foundation phase.
class SettingsController extends GetxController {
  final DocumentRepository _documentRepository;
  final RecentRepository _recentRepository;
  final PathService _pathService;

  SettingsController({
    DocumentRepository? documentRepository,
    RecentRepository? recentRepository,
    PathService? pathService,
  })  : _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _pathService = pathService ?? PathService.instance;

  ThemeController get themeController => Get.find<ThemeController>();

  final isRefreshingIndex = false.obs;
  final appVersion = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    appVersion.value = '${info.version} (${info.buildNumber})';
  }

  Future<void> refreshFileIndex() async {
    isRefreshingIndex.value = true;
    final result = await _documentRepository.rescan();
    isRefreshingIndex.value = false;
    result.fold(
      (failure) => CustomSnackbar.error(failure.message),
      (documents) => CustomSnackbar.success('Found ${documents.length} document(s).'),
    );
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
        } catch (e) {
          CustomSnackbar.error('Could not clear cache: $e');
        }
      },
    );
  }
}
