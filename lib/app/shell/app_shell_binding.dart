import 'package:get/get.dart';

import '../../core/presentation/controllers/document_interaction_controller.dart';
import '../../features/favorites/presentation/favorites_controller.dart';
import '../../features/files/presentation/files_controller.dart';
import '../../features/home/presentation/home_controller.dart';
import '../../features/settings/presentation/settings_controller.dart';
import 'app_shell_controller.dart';

class AppShellBinding extends Bindings {
  @override
  void dependencies() {
    // Registered first: Favorites/Files/Home/Search all read from this.
    Get.lazyPut<DocumentInteractionController>(() => DocumentInteractionController(), fenix: true);

    Get.lazyPut<AppShellController>(() => AppShellController());
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<FilesController>(() => FilesController(), fenix: true);
    Get.lazyPut<FavoritesController>(() => FavoritesController(), fenix: true);
    Get.lazyPut<SettingsController>(() => SettingsController(), fenix: true);
  }
}
