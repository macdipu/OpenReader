import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/show_dialog/show_dialog.dart';
import '../../../res/routes/app_routes.dart';
import 'recents_controller.dart';

class RecentsView extends GetView<RecentsController> {
  const RecentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClearAll(context),
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
                hintText: 'Search recent files',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.status.value.isBusy) return const LoadingView();
              final items = controller.filtered;
              if (items.isEmpty) return const CommonEmptyView(message: 'No history yet.');

              return ListView.builder(
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
                      ));
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showAppDialog<bool>(
      child: AlertDialog(
        title: const Text('Clear all recent files?'),
        content: const Text('This will not delete your documents.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearAll();
    }
  }
}
