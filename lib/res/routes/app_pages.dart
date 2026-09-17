import 'package:get/get_navigation/src/routes/get_route.dart';

import '../../app/shell/app_shell.dart';
import '../../app/shell/app_shell_binding.dart';
import '../../features/onboarding/presentation/onboarding_binding.dart';
import '../../features/onboarding/presentation/onboarding_view.dart';
import '../../features/recents/presentation/recents_binding.dart';
import '../../features/recents/presentation/recents_view.dart';
import '../../features/search/presentation/search_binding.dart';
import '../../features/search/presentation/search_view.dart';
import '../../features/splash/presentation/splash_binding.dart';
import '../../features/splash/presentation/splash_view.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = AppRoutes.splash;

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      bindings: [SplashBinding()],
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      bindings: [OnboardingBinding()],
    ),
    GetPage(
      name: AppRoutes.appShell,
      page: () => const AppShell(),
      bindings: [AppShellBinding()],
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchView(),
      bindings: [SearchBinding()],
    ),
    GetPage(
      name: AppRoutes.recents,
      page: () => const RecentsView(),
      bindings: [RecentsBinding()],
    ),
  ];
}
