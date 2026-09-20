import 'dart:async';

import 'package:get/get.dart';

import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/utils/state_status.dart';

/// File Search screen (BRD 9.7 - case-insensitive, partial-match filename search).
class SearchDocumentsController extends BaseController {
  final DocumentRepository _documentRepository;

  SearchDocumentsController({DocumentRepository? documentRepository})
      : _documentRepository = documentRepository ?? DocumentRepositoryImpl();

  final results = <DocumentModel>[].obs;
  final query = ''.obs;
  final selectedCategory = Rxn<DocumentCategory>();

  /// Client-side format filter on top of the filename-matched [results]
  /// (Local Search & Filter - DESIGN_SPEC.md #07).
  List<DocumentModel> get filteredResults {
    final category = selectedCategory.value;
    if (category == null) return results;
    return results.where((d) => d.category == category).toList();
  }

  void selectCategory(DocumentCategory? category) => selectedCategory.value = category;

  Timer? _debounce;

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      results.clear();
      status.value = StateStatus.initial;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () => _search(trimmed));
  }

  void clear() {
    query.value = '';
    results.clear();
    selectedCategory.value = null;
    status.value = StateStatus.initial;
    _debounce?.cancel();
  }

  Future<void> _search(String term) async {
    status.value = StateStatus.loading;
    final result = await _documentRepository.getDocuments(query: term);
    result.fold(
      (failure) => handleFailure(failure),
      (list) {
        results.assignAll(list);
        status.value = list.isEmpty ? StateStatus.empty : StateStatus.success;
      },
    );
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
