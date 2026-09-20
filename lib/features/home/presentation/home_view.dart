import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/relative_time_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../res/routes/app_routes.dart';
import '../../../services/utilities/storage_access_service.dart';
import 'home_controller.dart';

/// Home Discovery Hub (DESIGN_SPEC.md #08): search + format chips +
/// continue-reading carousel + recents list + scan FAB.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenReader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Get.toNamed(AppRoutes.search),
          ),
        ],
      ),
      floatingActionButton: Obx(() => controller.status.value.isBusy
          ? const SizedBox.shrink()
          : FloatingActionButton.extended(
              onPressed: controller.refresh,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Scan Storage'),
            )),
      body: Obx(() {
        if (!controller.hasAccess.value) {
          return _PermissionBanner(onRequestAccess: () async {
            final granted = await StorageAccessService.instance.requestAccess();
            if (granted) await controller.load();
          });
        }
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.status.value.isError) {
          return DocumentLoadErrorView(
            message: controller.errorMessage.value ?? 'Unable to load documents.',
            onRetry: controller.retry,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _SearchBarStub(onTap: () => Get.toNamed(AppRoutes.search)),
              ),
              const SizedBox(height: 16),
              _FormatChipRow(
                categoryCounts: controller.categoryCounts,
                onSelected: (category) =>
                    category == null ? controller.openAllFiles() : controller.openCategory(category),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Text(
                  '${controller.categoryCounts.values.fold<int>(0, (a, b) => a + b)} files indexed',
                  style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                ),
              ),
              if (controller.recentDocuments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text('Continue Reading', style: context.headlineSmall),
                ),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: controller.recentDocuments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final recent = controller.recentDocuments[index];
                      return _ContinueReadingCard(
                        recent: recent,
                        onTap: () => interactions.openDocument(recent.document),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Documents', style: context.headlineSmall),
                      TextButton(
                        onPressed: () => Get.toNamed(AppRoutes.recents),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                ),
                for (final recent in controller.recentDocuments)
                  Obx(() => DocumentListTile(
                        document: recent.document,
                        dense: true,
                        isFavorite: interactions.isFavorite(recent.document.id),
                        onTap: () => interactions.openDocument(recent.document),
                        onToggleFavorite: (_) => interactions.toggleFavorite(recent.document.id),
                        onShare: () => interactions.shareDocument(recent.document),
                        onShowInfo: () => Get.toNamed(AppRoutes.fileInformation, arguments: recent.document),
                        onOpenWith: () => interactions.openWithExternalApp(recent.document),
                        trailingLabel: 'Opened ${formatRelativeTime(recent.lastOpenedAt)}',
                      )),
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

/// Read-only search field that hands off to the dedicated Search screen
/// (Local Search & Filter), matching the Home Discovery Hub mock.
class _SearchBarStub extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBarStub({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: context.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Search documents', style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
            ),
            Icon(Icons.tune_rounded, color: context.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FormatChipRow extends StatelessWidget {
  final Map<DocumentCategory, int> categoryCounts;
  final ValueChanged<DocumentCategory?> onSelected;

  const _FormatChipRow({required this.categoryCounts, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final categories = DocumentCategory.values.where((c) => c != DocumentCategory.unknown).toList();
    final total = categoryCounts.values.fold<int>(0, (a, b) => a + b);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FormatChip(label: 'All', count: total, selected: true, onTap: () => onSelected(null)),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FormatChip(
                label: category.label,
                count: categoryCounts[category] ?? 0,
                accent: category.accentColor(context),
                onTap: () => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color? accent;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.count,
    this.accent,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.primary : context.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? context.primary : context.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!selected)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: accent ?? context.onSurfaceVariant, shape: BoxShape.circle),
              ),
            Text(
              label,
              style: context.labelMedium?.copyWith(color: selected ? context.onPrimary : context.onSurface),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: context.labelSmall?.copyWith(
                color: selected ? context.onPrimary.withValues(alpha: 0.7) : context.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final RecentDocumentModel recent;
  final VoidCallback onTap;

  const _ContinueReadingCard({required this.recent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final document = recent.document;
    final accent = document.category.accentColor(context);
    final tint = document.category.tintColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(6)),
              child: Icon(document.category.icon, size: 16, color: accent),
            ),
            const SizedBox(height: 10),
            Text(document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.titleSmall),
            const SizedBox(height: 2),
            Text(
              '${document.category.label} • ${formatFileSize(document.sizeBytes)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatRelativeTime(recent.lastOpenedAt), style: context.monoMetadata),
                Icon(Icons.play_arrow_rounded, color: context.secondary, size: 18),
              ],
            ),
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
              'OpenReader needs storage access to show your documents.',
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
