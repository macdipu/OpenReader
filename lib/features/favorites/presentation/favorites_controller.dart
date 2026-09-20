import 'package:get/get.dart';

import '../../../core/data/repositories/favorite_repository_impl.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/favorite_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';

/// Favorites screen (BRD 9.8).
class FavoritesController extends BaseController {
  final FavoriteRepository _favoriteRepository;

  FavoritesController({FavoriteRepository? favoriteRepository})
      : _favoriteRepository = favoriteRepository ?? FavoriteRepositoryImpl();

  final favorites = <DocumentModel>[].obs;
  final searchQuery = ''.obs;
  final selectedCategory = Rxn<DocumentCategory>();

  @override
  void onInit() {
    super.onInit();
    load();
    // Reload when a favorite is toggled from another screen (Home/Files/Search/Recents).
    ever(Get.find<DocumentInteractionController>().favoriteIds, (_) => load());
  }

  List<DocumentModel> get filtered {
    final query = searchQuery.value.trim().toLowerCase();
    final category = selectedCategory.value;
    return favorites.where((d) {
      final matchesQuery = query.isEmpty || d.displayName.toLowerCase().contains(query);
      final matchesCategory = category == null || d.category == category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  /// Per-format counts among the current favorites (DESIGN_SPEC #06 filter chips).
  Map<DocumentCategory, int> get categoryCounts {
    final counts = <DocumentCategory, int>{};
    for (final document in favorites) {
      counts[document.category] = (counts[document.category] ?? 0) + 1;
    }
    return counts;
  }

  void selectCategory(DocumentCategory? category) => selectedCategory.value = category;

  Future<void> load() async {
    status.value = StateStatus.loading;
    final result = await _favoriteRepository.getFavorites();
    result.fold(
      (failure) => handleFailure(failure),
      (list) {
        favorites.assignAll(list);
        status.value = list.isEmpty ? StateStatus.empty : StateStatus.success;
      },
    );
  }

  void setSearchQuery(String query) => searchQuery.value = query;
}
