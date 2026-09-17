import 'package:get/get.dart';

import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../services/utilities/storage_access_service.dart';

/// All Files screen with category filter, search-within, and sort
/// (BRD 9.4 - All Files Screen, 7.3 - File Sorting, 7.4 - File Filtering).
class FilesController extends BaseController {
  final DocumentRepository _documentRepository;
  final StorageAccessService _storageAccess;

  FilesController({
    DocumentRepository? documentRepository,
    StorageAccessService? storageAccess,
  })  : _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _storageAccess = storageAccess ?? StorageAccessService.instance;

  final documents = <DocumentModel>[].obs;
  final selectedCategory = Rxn<DocumentCategory>();
  final sortMode = DocumentSortMode.nameAsc.obs;
  final searchQuery = ''.obs;
  bool _retryScan = false;

  Future<void> retry() => _retryScan ? refresh() : load();

  final hasAccess = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    _retryScan = false;
    errorMessage.value = null;
    status.value = StateStatus.loading;
    hasAccess.value = await _storageAccess.hasAccess();
    if (!hasAccess.value) {
      status.value = StateStatus.empty;
      return;
    }

    final result = await _documentRepository.getDocuments(
      category: selectedCategory.value,
      query: searchQuery.value,
      sort: sortMode.value,
    );
    result.fold(
      (failure) => handleFailure(failure),
      (list) {
        documents.assignAll(list);
        status.value = list.isEmpty ? StateStatus.empty : StateStatus.success;
      },
    );
  }

  Future<void> refresh() async {
    _retryScan = true;
    status.value = StateStatus.refreshing;
    final rescanResult = await _documentRepository.rescan();
    await rescanResult.fold<Future<void>>(
      (failure) async => handleFailure(failure),
      (_) => load(),
    );
  }

  /// Invoked from Home when a category card is tapped (BRD 9.3).
  void selectCategory(DocumentCategory? category) {
    selectedCategory.value = category;
    load();
  }

  void setSort(DocumentSortMode mode) {
    sortMode.value = mode;
    load();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    load();
  }
}
