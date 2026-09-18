import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import 'csv_reader_controller.dart';

class CsvReaderBinding extends Bindings {
  @override
  void dependencies() {
    final document = Get.arguments as DocumentModel;
    Get.lazyPut<CsvReaderController>(() => CsvReaderController(document: document));
  }
}
