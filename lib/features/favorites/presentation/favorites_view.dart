import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/relative_time_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/show_dialog/show_dialog.dart';
import '../../../res/routes/app_routes.dart';
import '../../recents/presentation/recents_controller.dart';
import 'favorites_controller.dart';

/// Favorites & History (DESIGN_SPEC.md #06): segmented tabs for starred
/// documents vs. reading history.
class FavoritesView extends GetView<FavoritesController> {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();
    final recentsController = Get.find<RecentsController>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OpenReader'),
          bottom: TabBar(
            labelStyle: context.labelLarge,
            tabs: [
              Obx(() => Tab(text: 'Favorites (${controller.favorites.length})')),
              Obx(() => Tab(text: 'History (${recentsController.recents.length})')),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: () => _confirmClearHistory(context, recentsController),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _FavoritesTab(controller: controller, interactions: interactions),
            _HistoryTab(controller: recentsController, interactions: interactions),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, RecentsController recentsController) async {
    final confirmed = await showAppDialog<bool>(
      child: AlertDialog(
        title: const Text('Clear all reading history?'),
        content: const Text('This will not delete your documents.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) await recentsController.clearAll();
  }
}

class _FavoritesTab extends StatelessWidget {
  final FavoritesController controller;
  final DocumentInteractionController interactions;
  const _FavoritesTab({required this.controller, required this.interactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SearchField(hint: 'Search favorites', onChanged: controller.setSearchQuery),
        ),
        Expanded(
          child: Obx(() {
            if (controller.status.value.isBusy) return const LoadingView();
            final items = controller.filtered;
            if (items.isEmpty) return const CommonEmptyView(message: 'No favorite documents yet.');

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final document = items[index];
                return Obx(() => DocumentListTile(
                      document: document,
                      isFavorite: interactions.isFavorite(document.id),
                      onTap: () => interactions.openDocument(document),
                      onToggleFavorite: (_) => interactions.toggleFavorite(document.id),
                      onShare: () => interactions.shareDocument(document),
                      onShowInfo: () => Get.toNamed(AppRoutes.fileInformation, arguments: document),
                      onOpenWith: () => interactions.openWithExternalApp(document),
                    ));
              },
            );
          }),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final RecentsController controller;
  final DocumentInteractionController interactions;
  const _HistoryTab({required this.controller, required this.interactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SearchField(hint: 'Search history', onChanged: controller.setSearchQuery),
        ),
        Expanded(
          child: Obx(() {
            if (controller.status.value.isBusy) return const LoadingView();
            final items = controller.filtered;
            if (items.isEmpty) return const CommonEmptyView(message: 'No history yet.');

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final recent = items[index];
                return Obx(() => DocumentListTile(
                      document: recent.document,
                      isFavorite: interactions.isFavorite(recent.document.id),
                      onTap: () => interactions.openDocument(recent.document),
                      onToggleFavorite: (_) => interactions.toggleFavorite(recent.document.id),
                      onShare: () => interactions.shareDocument(recent.document),
                      onShowInfo: () => Get.toNamed(AppRoutes.fileInformation, arguments: recent.document),
                      onOpenWith: () => interactions.openWithExternalApp(recent.document),
                      onRemoveFromRecent: () => controller.removeOne(recent.document.id),
                      trailingLabel: 'Opened ${formatRelativeTime(recent.lastOpenedAt)}',
                    ));
              },
            );
          }),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: context.bodyMedium,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(Icons.search_rounded, color: context.onSurfaceVariant)),
    );
  }
}
