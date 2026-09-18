import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import 'file_information_controller.dart';

class FileInformationBinding extends Bindings {
  @override
  void dependencies() {
    final document = Get.arguments as DocumentModel;
    Get.lazyPut<FileInformationController>(() => FileInformationController(document: document));
  }
}
