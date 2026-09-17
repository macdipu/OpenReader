import '../models/recent_document_model.dart';
import '../usecase/usecase.dart';

abstract class RecentRepository {
  ResultFuture<List<RecentDocumentModel>> getRecents();

  /// Records that [documentId] was opened, updating its reading position.
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}});

  ResultFuture<void> remove(String documentId);

  ResultFuture<void> clearAll();
}
