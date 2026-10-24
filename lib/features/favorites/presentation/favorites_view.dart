import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/relative_time_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/show_dialog/confirm_dialog.dart';
import '../../file_information/presentation/file_information_view.dart';
import '../../recents/presentation/recents_controller.dart';
import 'favorites_controller.dart';
import '../../../app/shell/app_shell_controller.dart';
import '../../../core/presentation/utils/screen_utils.dart';

/// Favorites & History (DESIGN_SPEC.md #06): segmented tabs for starred
/// documents vs. reading history.
class FavoritesView extends GetView<FavoritesController> {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();
    final recentsController = Get.find<RecentsController>();

    return Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: TabBar(
            controller: controller.tabController,
            labelStyle: context.labelLarge,
            tabs: [
              Obx(() => Tab(text: 'Favorites (${controller.favorites.length})')),
              Obx(() => Tab(text: 'History (${recentsController.recents.length})')),
            ],
          ),
          actions: [
            Obx(() => controller.isHistoryTab.value
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear History',
                    onPressed: () => confirmClearHistory(recentsController),
                  )
                : const SizedBox.shrink()),
          ],
        ),
        body: TabBarView(
          controller: controller.tabController,
          children: [
            _FavoritesTab(controller: controller, interactions: interactions),
            _HistoryTab(controller: recentsController, interactions: interactions),
          ],
        ),
    );
  }
}

/// Shared by Library's History tab and Settings (UX-16).
Future<void> confirmClearHistory(RecentsController recentsController) async {
  final confirmed = await showConfirmDialog(
    title: 'Clear all reading history?',
    message: 'This will not delete your documents.',
    confirmLabel: 'Clear',
    destructive: true,
  );
  if (confirmed) await recentsController.clearAll();
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
        const SizedBox(height: 8),
        Obx(() => _CategoryChipRow(
              selected: controller.selectedCategory.value,
              counts: controller.categoryCounts,
              onSelected: controller.selectCategory,
            )),
        Expanded(
          child: Obx(() {
            if (controller.status.value.isLoading) return const LoadingView();
            final items = controller.filtered;
            if (items.isEmpty) {
              return CommonEmptyView(
                icon: Icons.star_outline_rounded,
                message: 'No favorite documents yet.',
                subtitle: 'Tap the star on any document to keep it here.',
                actionLabel: 'Browse Files',
                onAction: () => Get.find<AppShellController>().openBrowse(),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == items.length) {
                  final bytes = items.fold<int>(0, (sum, d) => sum + d.sizeBytes);
                  return _VaultFooterBanner(count: items.length, bytes: bytes);
                }
                final document = items[index];
                return Obx(() => DocumentListTile(
                      document: document,
                      isFavorite: interactions.isFavorite(document.id),
                      onTap: () => interactions.openDocument(document),
                      onToggleFavorite: (_) => interactions.toggleFavorite(document.id),
                      onShare: () => interactions.shareDocument(document),
                      onShowInfo: () => showFileInformationSheet(context, document),
                      onOpenWith: () => interactions.openWithExternalApp(document),
                      onDelete: () async {
                            if (await interactions.confirmAndDelete(document)) controller.load();
                          },
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
        const SizedBox(height: 8),
        Obx(() => _CategoryChipRow(
              selected: controller.selectedCategory.value,
              counts: controller.categoryCounts,
              onSelected: controller.selectCategory,
            )),
        Expanded(
          child: Obx(() {
            if (controller.status.value.isLoading) return const LoadingView();
            final items = controller.filtered;
            if (items.isEmpty) {
              return const CommonEmptyView(
                icon: Icons.history_rounded,
                message: 'No history yet.',
                subtitle: 'Documents you open will show up here.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == items.length) {
                  final bytes = items.fold<int>(0, (sum, r) => sum + r.document.sizeBytes);
                  return _VaultFooterBanner(count: items.length, bytes: bytes);
                }
                final recent = items[index];
                return Obx(() => DocumentListTile(
                      document: recent.document,
                      isFavorite: interactions.isFavorite(recent.document.id),
                      onTap: () => interactions.openDocument(recent.document),
                      onToggleFavorite: (_) => interactions.toggleFavorite(recent.document.id),
                      onShare: () => interactions.shareDocument(recent.document),
                      onShowInfo: () => showFileInformationSheet(context, recent.document),
                      onOpenWith: () => interactions.openWithExternalApp(recent.document),
                      onDelete: () async {
                            if (await interactions.confirmAndDelete(recent.document)) controller.load();
                          },
                      onRemoveFromRecent: () => controller.removeOne(recent.document.id),
                      trailingLabel: 'Opened ${formatRelativeTime(recent.lastOpenedAt)}',
                      progress: recent.progress,
                      readingPosition: recent.readingPosition,
                    ));
              },
            );
          }),
        ),
      ],
    );
  }
}

/// Format filter chips (DESIGN_SPEC #06 "Horizontal format filter chips").
class _CategoryChipRow extends StatelessWidget {
  final DocumentCategory? selected;
  final Map<DocumentCategory, int> counts;
  final ValueChanged<DocumentCategory?> onSelected;

  const _CategoryChipRow({required this.selected, required this.counts, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final categories = DocumentCategory.values.where((c) => c != DocumentCategory.unknown && counts.containsKey(c)).toList();
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox(height: 8);
    return SizedBox(
      height: context.scaledExtent(40),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(label: 'All', count: total, selected: selected == null, onTap: () => onSelected(null)),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Chip(
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

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, selected: selected, child: InkWell(
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
                style: context.labelSmall?.copyWith(color: selected ? context.onPrimary : context.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

/// Footer summary of the list: how many documents, and their total size.
class _VaultFooterBanner extends StatelessWidget {
  final int count;
  final int bytes;
  const _VaultFooterBanner({required this.count, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 16, color: context.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1 ? '1 document' : '$count documents',
              style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(formatFileSize(bytes), style: context.monoMetadata),
        ],
      ),
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
