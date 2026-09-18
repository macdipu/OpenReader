import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import 'word_reader_controller.dart';

class WordReaderBinding extends Bindings {
  @override
  void dependencies() {
    final document = Get.arguments as DocumentModel;
    Get.lazyPut<WordReaderController>(() => WordReaderController(document: document));
  }
}
