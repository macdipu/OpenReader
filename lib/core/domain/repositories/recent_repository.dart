import '../models/recent_document_model.dart';
import '../usecase/usecase.dart';

abstract class RecentRepository {
  ResultFuture<List<RecentDocumentModel>> getRecents();

  /// The stored reading position for [documentId], or an empty map if the
  /// document has no recorded position (never opened, or opened by a reader
  /// that doesn't persist a position). Reader screens use this to resume;
  /// use [getRecents] instead when the full history list is actually needed.
  ResultFuture<Map<String, Object?>> getPosition(String documentId);

  /// Records that [documentId] was opened, updating its reading position.
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}});

  /// Puts [documentId] in History as just opened, without touching a stored
  /// reading position (unlike [markOpened], which replaces it). A document
  /// opened and closed without scrolling still belongs in History.
  ResultFuture<void> touch(String documentId);

  ResultFuture<void> remove(String documentId);

  ResultFuture<void> clearAll();
}
