import 'package:get/get.dart';

import '../../core/domain/models/document_category.dart';
import '../../features/files/presentation/files_controller.dart';

class AppShellController extends GetxController {
  static const homeIndex = 0;
  static const filesIndex = 1;
  static const favoritesIndex = 2;
  static const settingsIndex = 3;

  final RxInt currentIndex = homeIndex.obs;

  void changeTab(int index) {
    currentIndex.value = index;
  }

  /// Switches to the Files tab, optionally pre-filtered to [category]
  /// (invoked from Home's category shortcuts, BRD 9.3).
  void openFiles({DocumentCategory? category}) {
    Get.find<FilesController>().selectCategory(category);
    currentIndex.value = filesIndex;
  }
}
