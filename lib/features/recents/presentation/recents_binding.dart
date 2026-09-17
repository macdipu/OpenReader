import 'package:get/get.dart';

import 'recents_controller.dart';

class RecentsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RecentsController>(() => RecentsController());
  }
}
