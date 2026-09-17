import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/utils/state_status.dart';

/// Recent Files screen (BRD 9.9).
class RecentsController extends BaseController {
  final RecentRepository _recentRepository;

  RecentsController({RecentRepository? recentRepository})
      : _recentRepository = recentRepository ?? RecentRepositoryImpl();

  final recents = <RecentDocumentModel>[].obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<RecentDocumentModel> get filtered {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return recents;
    return recents.where((r) => r.document.displayName.toLowerCase().contains(query)).toList();
  }

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
    result.fold((failure) => handleFailure(failure), (_) => load());
  }

  Future<void> clearAll() async {
    final result = await _recentRepository.clearAll();
    result.fold((failure) => handleFailure(failure), (_) => load());
  }

  void setSearchQuery(String query) => searchQuery.value = query;
}
