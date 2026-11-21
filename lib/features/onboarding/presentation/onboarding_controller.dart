import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/presentation/utils/storage_access_help.dart';
import '../../../res/routes/app_routes.dart';
import '../../../services/utilities/access_recheck.dart';
import '../../../services/utilities/storage_access_service.dart';

enum OnboardingStatus { initial, requesting, denied, permanentlyDenied }

/// Drives the storage-access permission flow (BRD 9.2). Scenarios A/B/C map
/// to [OnboardingStatus.initial]/[denied]/[permanentlyDenied].
class OnboardingController extends GetxController with WidgetsBindingObserver {
  final StorageAccessService _storageAccess;
  final AppSettingsRepository _settingsRepository;
  final AccessRecheck _recheck;

  OnboardingController({
    StorageAccessService? storageAccess,
    AppSettingsRepository? settingsRepository,
    AccessRecheck? recheck,
  })  : _storageAccess = storageAccess ?? StorageAccessService.instance,
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl(),
        _recheck = recheck ?? AccessRecheck();

  final status = OnboardingStatus.initial.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _recheck.cancel();
    super.onClose();
  }

  /// After a denial, the user may grant access from system settings ("Open
  /// Settings") - finish onboarding when they come back with it (UX-18).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (status.value != OnboardingStatus.denied && status.value != OnboardingStatus.permanentlyDenied) return;
    unawaited(_watchForGrant());
  }

  /// Checks at once and again over the next seconds: the grant can reach the app late.
  Future<void> _watchForGrant() => _recheck.run(
        check: _completeIfGranted,
        changed: () => _finished,
        isClosed: () => isClosed,
      );

  /// Set while a resume re-check runs, so a second resume during it can't
  /// finish onboarding twice. A private flag rather than `status`, which
  /// would briefly swap the denied screen for a spinner on every resume.
  bool _checkingAccess = false;

  /// Latched by [_finishWithAccess]: navigation and the first scan run
  /// once, however a resume re-check and an Allow tap interleave.
  bool _finished = false;

  Future<void> _completeIfGranted() async {
    if (_checkingAccess || _finished) return;
    _checkingAccess = true;
    try {
      if (await _storageAccess.hasAccess()) await _finishWithAccess();
    } finally {
      _checkingAccess = false;
    }
  }

  Future<void> allowAccess() async {
    if (_finished) return;
    status.value = OnboardingStatus.requesting;

    final granted = await _storageAccess.requestAccess();
    if (!granted) {
      status.value = await _storageAccess.isPermanentlyDenied()
          ? OnboardingStatus.permanentlyDenied
          : OnboardingStatus.denied;
      // Back from the OS page, the grant may show up a moment later.
      unawaited(_watchForGrant());
      return;
    }

    await _finishWithAccess();
  }

  Future<void> _finishWithAccess() async {
    if (_finished) return;
    _finished = true;
    await _settingsRepository.setOnboardingComplete(true);
    unawaited(Get.offAllNamed(AppRoutes.appShell));
  }

  /// "Get started" on iOS and desktop, where there is no permission step. Android has no way to
  /// skip: the access request is the one thing the first screen asks for.
  Future<void> continueWithoutAccess() async {
    // Same latch as the granted path: one navigation, however taps interleave.
    if (_finished) return;
    _finished = true;
    await _settingsRepository.setOnboardingComplete(true);
    unawaited(Get.offAllNamed(AppRoutes.appShell));
  }

  Future<void> openSettings() => _storageAccess.openSettings();

  /// The by-hand steps for this phone's brand and Android version.
  Future<StorageAccessHelp> accessHelp({String primaryLabel = StorageAccessHelp.openPageLabel}) =>
      loadStorageAccessHelp(_storageAccess, primaryLabel: primaryLabel);
}
