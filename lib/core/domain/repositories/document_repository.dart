import '../models/document_category.dart';
import '../models/document_model.dart';
import '../usecase/usecase.dart';

abstract class DocumentRepository {
  /// Re-scans local storage, persists the result, and returns the refreshed
  /// index (BRD 7.1 - Local Document Discovery). Files no longer found are
  /// dropped from the index but never touched on disk.
  ResultFuture<List<DocumentModel>> rescan();

  /// Inserts or updates a single document (BRD §7.7 "Open From Other Apps" -
  /// indexing a file another app hands to OpenDocs via an incoming intent).
  /// Unlike [rescan], this never removes any other row.
  ResultFuture<DocumentModel> indexDocument(DocumentModel document);

  ResultFuture<List<DocumentModel>> getDocuments({
    DocumentCategory? category,
    String? query,
    DocumentSortMode sort = DocumentSortMode.nameAsc,
  });

  ResultFuture<DocumentModel?> getById(String id);

  ResultFuture<int> countByCategory(DocumentCategory category);
}
