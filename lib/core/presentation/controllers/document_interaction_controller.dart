import 'package:get/get.dart';

import '../../data/repositories/favorite_repository_impl.dart';
import '../../data/repositories/recent_repository_impl.dart';
import '../../domain/models/document_model.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/recent_repository.dart';
import '../widgets/snackbar/custom_snackbar.dart';

/// Cross-screen document actions (favorite toggling, opening a document) and
/// the single reactive source of truth for favorite state, shared by Home,
/// Files, Search, Recents, and Favorites so a change made on one screen is
/// reflected on the others immediately.
class DocumentInteractionController extends GetxController {
  final FavoriteRepository _favoriteRepository;
  final RecentRepository _recentRepository;

  DocumentInteractionController({
    FavoriteRepository? favoriteRepository,
    RecentRepository? recentRepository,
  })  : _favoriteRepository = favoriteRepository ?? FavoriteRepositoryImpl(),
        _recentRepository = recentRepository ?? RecentRepositoryImpl();

  final favoriteIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshFavoriteIds();
  }

  Future<void> refreshFavoriteIds() async {
    final result = await _favoriteRepository.getFavorites();
    result.fold(
      (_) {},
      (documents) => favoriteIds.assignAll(documents.map((d) => d.id)),
    );
  }

  bool isFavorite(String documentId) => favoriteIds.contains(documentId);

  Future<void> toggleFavorite(String documentId) async {
    final wasFavorite = favoriteIds.contains(documentId);
    // Optimistic update; reconciled with the repository result below.
    if (wasFavorite) {
      favoriteIds.remove(documentId);
    } else {
      favoriteIds.add(documentId);
    }

    final result = await _favoriteRepository.toggle(documentId);
    result.fold(
      (failure) {
        // Revert on failure (BRD favorites must persist reliably).
        if (wasFavorite) {
          favoriteIds.add(documentId);
        } else {
          favoriteIds.remove(documentId);
        }
        CustomSnackbar.error(failure.message);
      },
      (_) {},
    );
  }

  /// Records the open in Recent History and hands off to a reader. Reader
  /// screens ship in BRD Phase 2/3; Phase 1 records the intent so Recents
  /// behaves correctly once a reader exists.
  Future<void> openDocument(DocumentModel document) async {
    await _recentRepository.markOpened(document.id);
    CustomSnackbar.info(
      '${document.category.label} reader is not part of this build yet.',
      title: document.displayName,
    );
  }

  Future<void> removeFromRecent(String documentId) => _recentRepository.remove(documentId);
}
