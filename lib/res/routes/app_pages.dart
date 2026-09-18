import 'package:get/get_navigation/src/routes/get_route.dart';

import '../../app/shell/app_shell.dart';
import '../../app/shell/app_shell_binding.dart';
import '../../features/file_information/presentation/file_information_binding.dart';
import '../../features/file_information/presentation/file_information_view.dart';
import '../../features/excel_reader/presentation/excel_reader_binding.dart';
import '../../features/excel_reader/presentation/excel_reader_view.dart';
import '../../features/onboarding/presentation/onboarding_binding.dart';
import '../../features/onboarding/presentation/onboarding_view.dart';
import '../../features/pdf_reader/presentation/pdf_reader_binding.dart';
import '../../features/pdf_reader/presentation/pdf_reader_view.dart';
import '../../features/recents/presentation/recents_binding.dart';
import '../../features/recents/presentation/recents_view.dart';
import '../../features/search/presentation/search_binding.dart';
import '../../features/search/presentation/search_view.dart';
import '../../features/splash/presentation/splash_binding.dart';
import '../../features/splash/presentation/splash_view.dart';
import '../../features/word_reader/presentation/word_reader_binding.dart';
import '../../features/word_reader/presentation/word_reader_view.dart';
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
    GetPage(
      name: AppRoutes.fileInformation,
      page: () => const FileInformationView(),
      bindings: [FileInformationBinding()],
    ),
    GetPage(
      name: AppRoutes.pdfReader,
      page: () => const PdfReaderView(),
      bindings: [PdfReaderBinding()],
    ),
    GetPage(
      name: AppRoutes.wordReader,
      page: () => const WordReaderView(),
      bindings: [WordReaderBinding()],
    ),
    GetPage(
      name: AppRoutes.excelReader,
      page: () => const ExcelReaderView(),
      bindings: [ExcelReaderBinding()],
    ),
  ];
}
