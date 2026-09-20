import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/empty/common_empty_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../res/routes/app_routes.dart';
import 'search_controller.dart';

/// Local Search & Filter (DESIGN_SPEC.md #07): search field, format filter
/// chips, result count, matched-substring highlighting.
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
          style: context.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Search documents',
            border: InputBorder.none,
          ),
        ),
        actions: [
          Obx(() => controller.query.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: controller.clear)),
        ],
      ),
      body: Obx(() {
        if (controller.status.value.isInitial) {
          return const CommonEmptyView(message: 'Search documents by filename.');
        }
        if (controller.status.value.isBusy) return const LoadingView();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Obx(() => _CategoryFilterRow(
                  selected: controller.selectedCategory.value,
                  onSelected: controller.selectCategory,
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '${controller.filteredResults.length} file(s) found',
                style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Builder(builder: (context) {
                final items = controller.filteredResults;
                if (items.isEmpty) return const CommonEmptyView(message: 'No results found.');
                return ListView.builder(
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
                          trailingLabel:
                              '${formatFileSize(document.sizeBytes)} • ${document.modifiedAt.toLocal().toString().split(' ').first}',
                        ));
                  },
                );
              }),
            ),
          ],
        );
      }),
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
          _Pill(label: 'All Formats', selected: selected == null, onTap: () => onSelected(null)),
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
