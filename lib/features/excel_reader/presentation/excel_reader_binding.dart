import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import 'excel_reader_controller.dart';

class ExcelReaderBinding extends Bindings {
  @override
  void dependencies() {
    final document = Get.arguments as DocumentModel;
    Get.lazyPut<ExcelReaderController>(() => ExcelReaderController(document: document));
  }
}
