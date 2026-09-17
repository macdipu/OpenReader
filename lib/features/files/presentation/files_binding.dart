import 'package:get/get.dart';

import 'files_controller.dart';

class FilesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FilesController>(() => FilesController(), fenix: true);
  }
}
