import '../models/document_model.dart';
import '../usecase/usecase.dart';

abstract class FavoriteRepository {
  ResultFuture<List<DocumentModel>> getFavorites();

  ResultFuture<bool> isFavorite(String documentId);

  ResultFuture<void> add(String documentId);

  ResultFuture<void> remove(String documentId);

  ResultFuture<void> toggle(String documentId);
}
