import 'dart:async';

import 'package:flutter/widgets.dart';
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
class OnboardingController extends GetxController with WidgetsBindingObserver {
  final StorageAccessService _storageAccess = StorageAccessService.instance;
  final AppSettingsRepository _settingsRepository = AppSettingsRepositoryImpl();
  final DocumentRepository _documentRepository = DocumentRepositoryImpl();

  final status = OnboardingStatus.initial.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// After a denial, the user may grant access from system settings ("Open
  /// Settings") - finish onboarding when they come back with it (UX-18).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (status.value != OnboardingStatus.denied && status.value != OnboardingStatus.permanentlyDenied) return;
    unawaited(_completeIfGranted());
  }

  Future<void> _completeIfGranted() async {
    // Leaves the denied states before awaiting, so a second resume (or an
    // Allow tap) during the check can't finish onboarding twice.
    final denied = status.value;
    status.value = OnboardingStatus.requesting;
    if (await _storageAccess.hasAccess()) {
      await _finishWithAccess();
    } else {
      status.value = denied;
    }
  }

  Future<void> allowAccess() async {
    status.value = OnboardingStatus.requesting;

    final granted = await _storageAccess.requestAccess();
    if (!granted) {
      status.value = await _storageAccess.isPermanentlyDenied()
          ? OnboardingStatus.permanentlyDenied
          : OnboardingStatus.denied;
      return;
    }

    await _finishWithAccess();
  }

  Future<void> _finishWithAccess() async {
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
