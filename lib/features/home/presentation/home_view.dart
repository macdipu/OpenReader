import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../res/routes/app_routes.dart';
import '../../../services/utilities/storage_access_service.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenDocs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed(AppRoutes.search),
          ),
        ],
      ),
      body: Obx(() {
        if (!controller.hasAccess.value) {
          return _PermissionBanner(onRequestAccess: () async {
            final granted = await StorageAccessService.instance.requestAccess();
            if (granted) await controller.load();
          });
        }
        if (controller.status.value.isBusy) return const LoadingView();

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Categories', style: context.titleMedium),
              ),
              SizedBox(
                height: 88,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final category in DocumentCategory.values.where((c) => c != DocumentCategory.unknown))
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _CategoryCard(
                          category: category,
                          count: controller.categoryCounts[category] ?? 0,
                          onTap: () => controller.openCategory(category),
                        ),
                      ),
                  ],
                ),
              ),
              if (controller.recentDocuments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Continue Reading', style: context.titleMedium),
                      TextButton(
                        onPressed: () => Get.toNamed(AppRoutes.recents),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                ),
                for (final recent in controller.recentDocuments)
                  DocumentListTile(
                    document: recent.document,
                    isFavorite: interactions.isFavorite(recent.document.id),
                    onTap: () => interactions.openDocument(recent.document),
                    onToggleFavorite: (_) => interactions.toggleFavorite(recent.document.id),
                    trailingLabel: 'Opened ${recent.lastOpenedAt.toLocal()}'.split('.').first,
                  ),
              ] else if (controller.status.value.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: CommonEmptyView(message: 'No documents found'),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final DocumentCategory category;
  final int count;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 84,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, color: context.primary),
            const SizedBox(height: 6),
            Text(category.label, style: context.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$count', style: context.labelSmall?.copyWith(color: context.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onRequestAccess;

  const _PermissionBanner({required this.onRequestAccess});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 56, color: context.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'OpenDocs needs storage access to show your documents.',
              textAlign: TextAlign.center,
              style: context.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRequestAccess, child: const Text('Grant Access')),
          ],
        ),
      ),
    );
  }
}
