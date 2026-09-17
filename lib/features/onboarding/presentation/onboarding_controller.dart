import 'dart:async';

import 'package:get/get.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../res/routes/app_routes.dart';
import '../../../services/utilities/storage_access_service.dart';

enum OnboardingStatus { initial, requesting, denied, permanentlyDenied }

/// Drives the storage-access permission flow (BRD 9.2). Scenarios A/B/C map
/// to [OnboardingStatus.initial]/[denied]/[permanentlyDenied].
class OnboardingController extends GetxController {
  final StorageAccessService _storageAccess = StorageAccessService.instance;
  final AppSettingsRepository _settingsRepository = AppSettingsRepositoryImpl();
  final DocumentRepository _documentRepository = DocumentRepositoryImpl();

  final status = OnboardingStatus.initial.obs;

  Future<void> allowAccess() async {
    status.value = OnboardingStatus.requesting;

    final granted = await _storageAccess.requestAccess();
    if (!granted) {
      status.value = await _storageAccess.isPermanentlyDenied()
          ? OnboardingStatus.permanentlyDenied
          : OnboardingStatus.denied;
      return;
    }

    await _settingsRepository.setOnboardingComplete(true);
    // Kick off the first scan; Home/Files will show empty/loading state
    // regardless if this hasn't finished by the time they mount.
    unawaited(_documentRepository.rescan());
    unawaited(Get.offAllNamed(AppRoutes.appShell));
  }

  /// Scenario B - user can continue in limited mode without storage access.
  Future<void> continueWithoutAccess() async {
    await _settingsRepository.setOnboardingComplete(true);
    unawaited(Get.offAllNamed(AppRoutes.appShell));
  }

  Future<void> openSettings() => _storageAccess.openSettings();
}
