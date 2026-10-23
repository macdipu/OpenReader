import '../models/document_category.dart';
import '../models/document_model.dart';
import '../usecase/usecase.dart';

abstract class DocumentRepository {
  /// Inserts or updates a single document: one opened from the browser or
  /// handed over by another app (BRD §7.7). The index holds only documents
  /// the user has opened (CR-OPENREADER-BROWSE); an update keeps the row's
  /// favorite and reading position.
  ResultFuture<DocumentModel> indexDocument(DocumentModel document);

  ResultFuture<List<DocumentModel>> getDocuments({
    DocumentCategory? category,
    String? query,
    DocumentSortMode sort = DocumentSortMode.nameAsc,
  });

  ResultFuture<DocumentModel?> getById(String id);

  ResultFuture<int> countByCategory(DocumentCategory category);

  /// Permanently deletes the file from device storage, then drops its index
  /// row (favorite/recent metadata cascades with it). A file that is already
  /// gone still has its row removed.
  ResultFuture<void> deleteDocument(DocumentModel document);
}
