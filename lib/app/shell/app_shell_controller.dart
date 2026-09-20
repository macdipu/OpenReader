import 'dart:async';

import 'package:get/get.dart';

import '../../core/domain/models/document_category.dart';
import '../../features/favorites/presentation/favorites_controller.dart';
import '../../features/files/presentation/files_controller.dart';
import '../../features/home/presentation/home_controller.dart';
import '../../services/platform_integration/incoming_intent_service.dart';

class AppShellController extends GetxController {
  static const homeIndex = 0;
  static const filesIndex = 1;
  static const favoritesIndex = 2;

  final RxInt currentIndex = homeIndex.obs;

  final IncomingIntentService _incomingIntentService;

  AppShellController({IncomingIntentService? incomingIntentService}) : _incomingIntentService = incomingIntentService ?? IncomingIntentService();

  @override
  void onInit() {
    super.onInit();
    // BRD §7.7 / TASK-009: by the time the shell exists, onboarding/storage
    // access has already been resolved, so it's safe to start listening for
    // an incoming file here.
    unawaited(_incomingIntentService.init());
  }

  @override
  void onClose() {
    _incomingIntentService.dispose();
    super.onClose();
  }

  void changeTab(int index) {
    currentIndex.value = index;
    // Belt-and-suspenders reload on tab select: verified on a real device
    // that FavoritesController's own `ever(...favoriteIds...)` reactive
    // subscription (favorites_controller.dart) does not reliably pick up a
    // favorite toggled from a different screen (e.g. Files' context menu)
    // once the Favorites tab has already been visited once this session —
    // the database write succeeds but the tab keeps showing its old list
    // until this. Root cause in the reactive chain itself wasn't isolated
    // further; reloading on every tab-select is small and guaranteed
    // correct regardless of it.
    if (index == favoritesIndex) {
      Get.find<FavoritesController>().load();
    }
    // Same reasoning as above, for Home's Recent Documents/Continue Reading
    // list: Settings > "Clear Recent History" and Favorites' History tab
    // both clear via their own RecentRepository call without notifying
    // Home's separate `recentDocuments` list, which would otherwise show a
    // stale (already-deleted) history until the app restarts.
    if (index == homeIndex) {
      Get.find<HomeController>().load();
    }
  }

  /// Switches to the Files tab, optionally pre-filtered to [category]
  /// (invoked from Home's category shortcuts, BRD 9.3).
  void openFiles({DocumentCategory? category}) {
    Get.find<FilesController>().selectCategory(category);
    currentIndex.value = filesIndex;
  }
}
