import 'package:get/get.dart';

import '../../../core/data/repositories/favorite_repository_impl.dart';
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

  @override
  void onInit() {
    super.onInit();
    load();
    // Reload when a favorite is toggled from another screen (Home/Files/Search/Recents).
    ever(Get.find<DocumentInteractionController>().favoriteIds, (_) => load());
  }

  List<DocumentModel> get filtered {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return favorites;
    return favorites.where((d) => d.displayName.toLowerCase().contains(query)).toList();
  }

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
