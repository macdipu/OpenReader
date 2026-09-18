import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import 'text_reader_controller.dart';

class TextReaderBinding extends Bindings {
  @override
  void dependencies() {
    final document = Get.arguments as DocumentModel;
    Get.lazyPut<TextReaderController>(() => TextReaderController(document: document));
  }
}
