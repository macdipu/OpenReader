import 'package:get/get.dart';

import '../../core/presentation/controllers/document_interaction_controller.dart';
import '../../features/favorites/presentation/favorites_controller.dart';
import '../../features/files/presentation/files_controller.dart';
import '../../features/home/presentation/home_controller.dart';
import '../../features/recents/presentation/recents_controller.dart';
import 'app_shell_controller.dart';

class AppShellBinding extends Bindings {
  @override
  void dependencies() {
    // Registered first: Favorites/Files/Home/Search all read from this.
    //
    // Eager `Get.put(permanent: true)`, not `Get.lazyPut(fenix: true)`:
    // verified on a real device that `FavoritesController.onInit()`'s
    // one-time `ever(...favoriteIds...)` subscription
    // (favorites_controller.dart) goes permanently stale if this controller
    // is ever disposed and lazily recreated (what `fenix` allows) —
    // toggling a favorite from a reader after that point updates the
    // database correctly but the Favorites tab never reflects it again for
    // the rest of the session, despite the class's own doc comment already
    // promising it is "the single reactive source of truth ... shared by
    // Home, Files, Search, Recents, and Favorites". `permanent` keeps one
    // stable instance identity for the whole app lifetime instead (`Get.put`
    // because `Get.lazyPut` has no `permanent` parameter in this GetX
    // version — only `fenix`, which is the behavior being removed here).
    Get.put<DocumentInteractionController>(DocumentInteractionController(), permanent: true);

    Get.lazyPut<AppShellController>(() => AppShellController());
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<FilesController>(() => FilesController(), fenix: true);
    Get.lazyPut<FavoritesController>(() => FavoritesController(), fenix: true);
    // Favorites & History screen shows both tabs together (DESIGN_SPEC #06),
    // so History needs to be available as soon as the Favorites tab is.
    Get.lazyPut<RecentsController>(() => RecentsController(), fenix: true);
    // Settings is a pushed route now (see AppRoutes.settings), not a shell
    // tab - SettingsBinding registers its own controller.
  }
}
