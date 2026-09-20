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
import '../../file_information/presentation/file_information_view.dart';
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('All Files'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('LOCAL', style: context.monoMetadata),
            ),
          ],
        ),
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
                // `Map.of(...)` (not a bare reference) so this Obx actually
                // reads the RxMap's entries and subscribes to it - passing
                // the RxMap through unread never registers a dependency, so
                // `categoryCounts.assignAll(...)` would otherwise silently
                // never repaint this row.
                counts: Map.of(controller.categoryCounts),
                onSelected: controller.selectCategory,
              )),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Obx(() => _SortChip(mode: controller.sortMode.value, onSelected: controller.setSort)),
            ),
          ),
          const SizedBox(height: 4),
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
                          onTap: () => _showFileActionSheet(context, document, interactions),
                          onToggleFavorite: (_) => interactions.toggleFavorite(document.id),
                          onShare: () => interactions.shareDocument(document),
                          onShowInfo: () => showFileInformationSheet(context, document),
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
  final Map<DocumentCategory, int> counts;
  final ValueChanged<DocumentCategory?> onSelected;

  const _CategoryFilterRow({required this.selected, required this.counts, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final categories = DocumentCategory.values.where((c) => c != DocumentCategory.unknown).toList();
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Pill(label: 'All', count: total, selected: selected == null, onTap: () => onSelected(null)),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Pill(
                label: category.label,
                count: counts[category] ?? 0,
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
  final int count;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.count,
    required this.selected,
    this.accent,
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
            if (!selected && accent != null) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Text(label, style: context.labelMedium?.copyWith(color: selected ? context.onPrimary : context.onSurface)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? context.onPrimary.withValues(alpha: 0.2) : context.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: context.labelSmall?.copyWith(
                  color: selected ? context.onPrimary : context.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visible "current sort" chip (DESIGN_SPEC #10 "Sort/view sub-bar") that
/// opens the same sort menu previously hidden behind an app-bar icon.
class _SortChip extends StatelessWidget {
  final DocumentSortMode mode;
  final ValueChanged<DocumentSortMode> onSelected;

  const _SortChip({required this.mode, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DocumentSortMode>(
      onSelected: onSelected,
      itemBuilder: (context) =>
          DocumentSortMode.values.map((m) => PopupMenuItem(value: m, child: Text(m.label))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 16, color: context.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(mode.label, style: context.labelMedium?.copyWith(color: context.onSurface)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: context.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet action list on row tap (DESIGN_SPEC #10 "Bottom sheet
/// modal"): Open in Reader / Favorite / Share / Info / Open With.
Future<void> _showFileActionSheet(
  BuildContext context,
  DocumentModel document,
  DocumentInteractionController interactions,
) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      final accent = document.category.accentColor(sheetContext);
      final tint = document.category.tintColor(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetContext.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      document.category.shortCode,
                      style: sheetContext.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: sheetContext.titleMedium),
                        Text(
                          '${formatFileSize(document.sizeBytes)} • ${document.category.label}',
                          style: sheetContext.bodySmall?.copyWith(color: sheetContext.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(sheetContext).pop()),
                ],
              ),
            ),
            const Divider(height: 24),
            _SheetAction(
              icon: Icons.menu_book_outlined,
              title: 'Open in Reader',
              onTap: () {
                Navigator.of(sheetContext).pop();
                interactions.openDocument(document);
              },
            ),
            Obx(() => _SheetAction(
                  icon: interactions.isFavorite(document.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                  title: interactions.isFavorite(document.id) ? 'Remove from Favorites' : 'Add to Favorites',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    interactions.toggleFavorite(document.id);
                  },
                )),
            _SheetAction(
              icon: Icons.share_outlined,
              title: 'Share File',
              onTap: () {
                Navigator.of(sheetContext).pop();
                interactions.shareDocument(document);
              },
            ),
            _SheetAction(
              icon: Icons.info_outline,
              title: 'File Information',
              onTap: () {
                Navigator.of(sheetContext).pop();
                showFileInformationSheet(context, document);
              },
            ),
            _SheetAction(
              icon: Icons.open_in_new_rounded,
              title: 'Open With (External App)',
              onTap: () {
                Navigator.of(sheetContext).pop();
                interactions.openWithExternalApp(document);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SheetAction({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.onSurfaceVariant),
      title: Text(title, style: context.bodyLarge),
      onTap: onTap,
    );
  }
}
