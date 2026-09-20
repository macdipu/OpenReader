import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../home/presentation/home_controller.dart';

/// Recent Files screen (BRD 9.9).
class RecentsController extends BaseController {
  final RecentRepository _recentRepository;

  RecentsController({RecentRepository? recentRepository})
      : _recentRepository = recentRepository ?? RecentRepositoryImpl();

  final recents = <RecentDocumentModel>[].obs;
  final searchQuery = ''.obs;
  final selectedCategory = Rxn<DocumentCategory>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<RecentDocumentModel> get filtered {
    final query = searchQuery.value.trim().toLowerCase();
    final category = selectedCategory.value;
    return recents.where((r) {
      final matchesQuery = query.isEmpty || r.document.displayName.toLowerCase().contains(query);
      final matchesCategory = category == null || r.document.category == category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  /// Per-format counts among current history (DESIGN_SPEC #06 filter chips).
  Map<DocumentCategory, int> get categoryCounts {
    final counts = <DocumentCategory, int>{};
    for (final recent in recents) {
      counts[recent.document.category] = (counts[recent.document.category] ?? 0) + 1;
    }
    return counts;
  }

  void selectCategory(DocumentCategory? category) => selectedCategory.value = category;

  Future<void> load() async {
    status.value = StateStatus.loading;
    final result = await _recentRepository.getRecents();
    result.fold(
      (failure) => handleFailure(failure),
      (list) {
        recents.assignAll(list);
        status.value = list.isEmpty ? StateStatus.empty : StateStatus.success;
      },
    );
  }

  Future<void> removeOne(String documentId) async {
    final result = await _recentRepository.remove(documentId);
    await result.fold((failure) async => handleFailure(failure), (_) async {
      await load();
      await _refreshHome();
    });
  }

  Future<void> clearAll() async {
    final result = await _recentRepository.clearAll();
    await result.fold((failure) async => handleFailure(failure), (_) async {
      await load();
      await _refreshHome();
    });
  }

  /// This controller backs both the standalone Recents route and the
  /// History tab inside Favorites - either can mutate history behind Home's
  /// back, since Home keeps its own separate `recentDocuments` list.
  Future<void> _refreshHome() async {
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().load();
    }
  }

  void setSearchQuery(String query) => searchQuery.value = query;
}
