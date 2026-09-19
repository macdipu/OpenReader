import 'package:get/get.dart';

import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Eager `Get.put`, not `Get.lazyPut`: SplashView never reads `controller`
    // in its build() (it's a static loading screen), so a lazy registration
    // is never resolved via Get.find() and SplashController.onInit() (which
    // drives the bootstrap-and-navigate-away logic) never runs — the app
    // gets stuck on this screen forever. Verified on a real emulator; see
    // FEATURE-OPENREADER-P5/tasks/TASK-013.md.
    Get.put<SplashController>(SplashController());
  }
}
