import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../res/routes/app_routes.dart';
import 'files_controller.dart';

/// All Files Explorer (DESIGN_SPEC.md #10): format filter pills, storage
/// summary banner, sort chip, compact file rows.
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
            icon: const Icon(Icons.sort_rounded),
            onSelected: controller.setSort,
            itemBuilder: (context) =>
                DocumentSortMode.values.map((mode) => PopupMenuItem(value: mode, child: Text(mode.label))).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _SearchField(onChanged: controller.setSearchQuery),
          ),
          const SizedBox(height: 12),
          Obx(() => _CategoryFilterRow(
                selected: controller.selectedCategory.value,
                onSelected: controller.selectCategory,
              )),
          Expanded(
            child: Obx(() {
              if (!controller.hasAccess.value) {
                return const CommonEmptyView(message: 'Storage access is required to list files.');
              }
              if (controller.status.value.isBusy) return const LoadingView();
              if (controller.status.value.isError) {
                return DocumentLoadErrorView(
                  message: controller.errorMessage.value ?? 'Unable to load documents.',
                  onRetry: controller.retry,
                );
              }
              if (controller.status.value.isEmpty) {
                return const CommonEmptyView(message: 'No documents found');
              }
              return RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: controller.documents.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _StorageSummaryBanner(documents: controller.documents);
                    final document = controller.documents[index - 1];
                    return Obx(() => DocumentListTile(
                          document: document,
                          dense: true,
                          isFavorite: interactions.isFavorite(document.id),
                          onTap: () => interactions.openDocument(document),
                          onToggleFavorite: (_) => interactions.toggleFavorite(document.id),
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

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: context.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Search this list',
        prefixIcon: Icon(Icons.search_rounded, color: context.onSurfaceVariant),
      ),
    );
  }
}

class _StorageSummaryBanner extends StatelessWidget {
  final List<DocumentModel> documents;
  const _StorageSummaryBanner({required this.documents});

  @override
  Widget build(BuildContext context) {
    final totalBytes = documents.fold<int>(0, (sum, d) => sum + d.sizeBytes);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: context.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${documents.length} documents • ${formatFileSize(totalBytes)} total • Zero network sync',
              style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.outlineVariant),
            ),
            child: Text('SANDBOXED', style: context.monoMetadata),
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
    final categories = DocumentCategory.values.where((c) => c != DocumentCategory.unknown).toList();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Pill(label: 'All', selected: selected == null, onTap: () => onSelected(null)),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Pill(
                label: category.label,
                selected: selected == category,
                accent: category.accentColor(context),
                onTap: () => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.selected, this.accent, required this.onTap});

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
            if (!selected && accent != null) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Text(label, style: context.labelMedium?.copyWith(color: selected ? context.onPrimary : context.onSurface)),
          ],
        ),
      ),
    );
  }
}
