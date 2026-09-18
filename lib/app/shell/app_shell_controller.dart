import 'dart:async';

import 'package:get/get.dart';

import '../../core/domain/models/document_category.dart';
import '../../features/files/presentation/files_controller.dart';
import '../../services/platform_integration/incoming_intent_service.dart';

class AppShellController extends GetxController {
  static const homeIndex = 0;
  static const filesIndex = 1;
  static const favoritesIndex = 2;
  static const settingsIndex = 3;

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
  }

  /// Switches to the Files tab, optionally pre-filtered to [category]
  /// (invoked from Home's category shortcuts, BRD 9.3).
  void openFiles({DocumentCategory? category}) {
    Get.find<FilesController>().selectCategory(category);
    currentIndex.value = filesIndex;
  }
}
