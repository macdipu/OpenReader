import 'dart:async';

import 'package:get/get.dart';

import '../../../core/data/local/app_database.dart';
import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/presentation/utils/logger.dart';
import '../../../res/routes/app_routes.dart';

/// Initializes local services then routes to onboarding or the app shell
/// (BRD 9.1 - Splash / Initialization Screen).
class SplashController extends GetxController {
  final AppSettingsRepository _settingsRepository = AppSettingsRepositoryImpl();

  @override
  void onInit() {
    super.onInit();
    _bootstrapAndRoute();
  }

  static const _bootstrapTimeout = Duration(seconds: 5);

  Future<void> _bootstrapAndRoute() async {
    var onboardingComplete = false;
    try {
      // Opens (and, on first run, creates) the local document/recent/favorite
      // database so the app shell never hits a cold-open delay.
      //
      // Wrapped in a timeout: a plain try/catch only guards against a thrown
      // exception, not a platform call that never completes.
      await Future(() async {
        await AppDatabase.instance.database;
        onboardingComplete = await _settingsRepository.hasCompletedOnboarding();
      }).timeout(_bootstrapTimeout);
    } catch (e) {
      // BRD 9.1 corner case: never block permanently on splash. Fall back to
      // onboarding so the user can still proceed even if local state is unreadable.
      AppLogger.error('Splash initialization failed, falling back to onboarding', e);
    }

    unawaited(Get.offAllNamed(onboardingComplete ? AppRoutes.appShell : AppRoutes.onboarding));
  }
}
