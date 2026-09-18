import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import 'pdf_reader_controller.dart';

class PdfReaderBinding extends Bindings {
  @override
  void dependencies() {
    final document = Get.arguments as DocumentModel;
    Get.lazyPut<PdfReaderController>(() => PdfReaderController(document: document));
  }
}
