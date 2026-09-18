import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../res/routes/app_routes.dart';
import 'files_controller.dart';

class FilesView extends GetView<FilesController> {
  const FilesView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Files'),
        actions: [
          PopupMenuButton<DocumentSortMode>(
            icon: const Icon(Icons.sort),
            onSelected: controller.setSort,
            itemBuilder: (context) => DocumentSortMode.values
                .map((mode) =>
                    PopupMenuItem(value: mode, child: Text(mode.label)))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: controller.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search this list',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Obx(() => _CategoryFilterRow(
                  selected: controller.selectedCategory.value,
                  onSelected: controller.selectCategory,
                )),
          ),
          Expanded(
            child: Obx(() {
              if (!controller.hasAccess.value) {
                return const CommonEmptyView(
                    message: 'Storage access is required to list files.');
              }
              if (controller.status.value.isBusy) return const LoadingView();
              if (controller.status.value.isError) {
                return DocumentLoadErrorView(
                  message: controller.errorMessage.value ??
                      'Unable to load documents.',
                  onRetry: controller.retry,
                );
              }
              if (controller.status.value.isEmpty) {
                return const CommonEmptyView(message: 'No documents found');
              }
              return RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.builder(
                  itemCount: controller.documents.length,
                  itemBuilder: (context, index) {
                    final document = controller.documents[index];
                    return Obx(() => DocumentListTile(
                          document: document,
                          isFavorite: interactions.isFavorite(document.id),
                          onTap: () => interactions.openDocument(document),
                          onToggleFavorite: (_) =>
                              interactions.toggleFavorite(document.id),
                          onShare: () => interactions.shareDocument(document),
                          onShowInfo: () => Get.toNamed(AppRoutes.fileInformation, arguments: document),
                          onOpenWith: () => interactions.openWithExternalApp(document),
                        ));
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  final DocumentCategory? selected;
  final ValueChanged<DocumentCategory?> onSelected;

  const _CategoryFilterRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final categories = DocumentCategory.values
        .where((c) => c != DocumentCategory.unknown)
        .toList();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.label),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}
