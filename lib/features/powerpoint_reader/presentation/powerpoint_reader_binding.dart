import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import 'powerpoint_reader_controller.dart';

class PowerPointReaderBinding extends Bindings {
  @override
  void dependencies() {
    final document = Get.arguments as DocumentModel;
    Get.lazyPut<PowerPointReaderController>(() => PowerPointReaderController(document: document));
  }
}
