import 'package:get/get.dart';

import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../../../app/shell/app_shell_controller.dart';

/// Home screen: category shortcuts, Continue Reading, Recent Documents
/// (BRD 9.3).
class HomeController extends BaseController {
  final DocumentRepository _documentRepository;
  final RecentRepository _recentRepository;
  final StorageAccessService _storageAccess;

  HomeController({
    DocumentRepository? documentRepository,
    RecentRepository? recentRepository,
    StorageAccessService? storageAccess,
  })  : _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _storageAccess = storageAccess ?? StorageAccessService.instance;

  static const _maxRecentPreview = 5;

  final hasAccess = true.obs;
  final categoryCounts = <DocumentCategory, int>{}.obs;
  final recentDocuments = <RecentDocumentModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status.value = StateStatus.loading;
    hasAccess.value = await _storageAccess.hasAccess();
    if (!hasAccess.value) {
      status.value = StateStatus.empty;
      return;
    }

    await Future.wait([_loadCounts(), _loadRecents()]);
    status.value = StateStatus.success;
  }

  Future<void> refresh() async {
    status.value = StateStatus.refreshing;
    final result = await _documentRepository.rescan();
    result.fold((failure) => handleFailure(failure), (_) {});
    await load();
  }

  Future<void> _loadCounts() async {
    final counts = <DocumentCategory, int>{};
    for (final category in DocumentCategory.values.where((c) => c != DocumentCategory.unknown)) {
      final result = await _documentRepository.countByCategory(category);
      result.fold((_) {}, (count) => counts[category] = count);
    }
    categoryCounts.assignAll(counts);
  }

  Future<void> _loadRecents() async {
    final result = await _recentRepository.getRecents();
    result.fold(
      (_) {},
      (list) => recentDocuments.assignAll(list.take(_maxRecentPreview).toList()),
    );
  }

  void openCategory(DocumentCategory category) {
    Get.find<AppShellController>().openFiles(category: category);
  }

  void openAllFiles() {
    Get.find<AppShellController>().openFiles();
  }
}
