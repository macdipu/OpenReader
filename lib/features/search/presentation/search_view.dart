import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../res/routes/app_routes.dart';
import 'search_controller.dart';

class SearchView extends GetView<SearchDocumentsController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: controller.onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search documents',
            border: InputBorder.none,
          ),
        ),
        actions: [
          Obx(() => controller.query.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(icon: const Icon(Icons.clear), onPressed: controller.clear)),
        ],
      ),
      body: Obx(() {
        if (controller.status.value.isInitial) {
          return const CommonEmptyView(message: 'Search documents by filename.');
        }
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.status.value.isEmpty) {
          return const CommonEmptyView(message: 'No results found.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '${controller.results.length} result(s)',
                style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: controller.results.length,
                itemBuilder: (context, index) {
                  final document = controller.results[index];
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
              ),
            ),
          ],
        );
      }),
    );
  }
}
