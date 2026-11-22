import '../models/document_category.dart';
import '../models/document_model.dart';
import '../models/keep_state.dart';
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

  /// The decision the user made about a shared copy (CR-FILE-RELOCATE), or null when there is none.
  ResultFuture<KeepState?> getKeepState(String documentId);

  /// Records the decision; null clears it. Does nothing for an id that is not indexed.
  ResultFuture<void> setKeepState(String documentId, KeepState? state);

  /// Paths of the documents that a recent entry or a favorite points at: copies among them must
  /// not be pruned.
  ResultFuture<Set<String>> referencedPaths();

  /// Moves [oldId] history, favorite and reading position to [replacement] (a file that took its
  /// place: located by the user, or saved from a shared copy), then drops the old row.
  ///
  /// Where [replacement] already has history, the more recently opened entry wins and a favorite on
  /// either is kept. [keepState] is stored on the replacement (null leaves none). The file at the
  /// old path is not touched.
  ResultFuture<DocumentModel> relink(String oldId, DocumentModel replacement, {KeepState? keepState});
}
