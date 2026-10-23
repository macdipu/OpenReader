import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../file_information/presentation/file_information_view.dart';
import 'package:path/path.dart' as p;

import '../../../app/shell/app_shell_controller.dart';
import 'browse_controller.dart';
import '../../../core/presentation/utils/screen_utils.dart';

/// The Browse tab (CR-OPENREADER-BROWSE): storage roots, then folders with
/// their supported documents. Replaces the former All Files list of a
/// whole-storage scan.
class BrowseView extends GetView<BrowseController> {
  const BrowseView({super.key});

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();

    return Obx(() => PopScope(
          // Back goes up a folder (or out of search results) before leaving -
          // only while this tab is showing: the shell keeps every tab mounted,
          // so otherwise back on Home would move Browse instead of exiting.
          canPop: !_isActiveTab || (controller.atRoots && !controller.showingSearch.value),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.goUp();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: controller.atRoots && !controller.showingSearch.value
                  ? null
                  : IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: controller.goUp,
                    ),
              title: Text(controller.showingSearch.value ? 'Search results' : 'Browse'),
            ),
            body: Column(
              children: [
                if (!controller.atRoots && !controller.showingSearch.value) _Breadcrumb(controller: controller),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  // Keyed, so the field keeps its state while rows above and
                  // below it come and go (breadcrumb, filters, search results).
                  child: _SearchField(key: const ValueKey('browse-search'), controller: controller),
                ),
                if (!controller.atRoots && !controller.showingSearch.value) ...[
                  const SizedBox(height: 12),
                  _CategoryFilterRow(
                    selected: controller.selectedCategory.value,
                    counts: controller.categoryCounts,
                    onSelected: controller.selectCategory,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _SortChip(mode: controller.sortMode.value, onSelected: controller.setSort),
                    ),
                  ),
                ],
                SizedBox(
                  height: 2,
                  child: controller.status.value.isRefreshing || controller.isSearching.value
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                Expanded(child: _body(context, interactions)),
              ],
            ),
          ),
        ));
  }

  /// Whether the shell is showing this tab (always true outside the shell).
  bool get _isActiveTab =>
      !Get.isRegistered<AppShellController>() ||
      Get.find<AppShellController>().currentIndex.value == AppShellController.filesIndex;

  Widget _body(BuildContext context, DocumentInteractionController interactions) {
    if (!controller.hasAccess.value) {
      return _FilesMessage(
        icon: Icons.folder_off_outlined,
        message: 'Storage access is needed to browse your files.',
        actionLabel: 'Grant Access',
        onAction: controller.requestAccess,
      );
    }
    if (controller.status.value.isLoading) return const LoadingView();
    if (controller.showingSearch.value) return _searchResults(context, interactions);
    if (controller.atRoots) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final root in controller.roots)
            ListTile(
              leading: Icon(Icons.sd_storage_outlined, color: context.secondary),
              title: Text(root.name, style: context.titleMedium),
              subtitle: Text(root.path, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => controller.openRoot(root),
            ),
        ],
      );
    }
    if (controller.denied.value) {
      return const _FilesMessage(icon: Icons.lock_outline_rounded, message: "This folder can't be opened.");
    }
    final folders = controller.visibleFolders;
    final documents = controller.visibleDocuments;
    if (folders.isEmpty && documents.isEmpty) {
      return _FilesMessage(
        icon: Icons.folder_open_outlined,
        message: controller.documents.isEmpty && controller.folders.isEmpty
            ? 'This folder has no documents.'
            : 'Nothing here matches.',
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: folders.length + documents.length,
        itemBuilder: (context, index) {
          if (index < folders.length) {
            final folder = folders[index];
            return ListTile(
              leading: Icon(Icons.folder_rounded, color: context.secondary),
              title: Text(p.basename(folder.path), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => controller.openFolder(folder.path),
            );
          }
          return _documentTile(context, interactions, documents[index - folders.length], controller.filter.value);
        },
      ),
    );
  }

  Widget _searchResults(BuildContext context, DocumentInteractionController interactions) {
    final results = controller.searchResults;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  controller.isSearching.value
                      ? 'Searching for "${controller.searchQuery.value}"… ${results.length} found'
                      : '${results.length} found for "${controller.searchQuery.value}"',
                  style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                ),
              ),
              if (controller.isSearching.value)
                TextButton(onPressed: controller.cancelSearch, child: const Text('Stop')),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty && !controller.isSearching.value
              ? const _FilesMessage(icon: Icons.search_off_rounded, message: 'No matching documents.')
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: results.length,
                  itemBuilder: (context, index) =>
                      _documentTile(context, interactions, results[index], controller.searchQuery.value, showFolder: true),
                ),
        ),
      ],
    );
  }

  Widget _documentTile(
    BuildContext context,
    DocumentInteractionController interactions,
    DocumentModel document,
    String highlight, {
    bool showFolder = false,
  }) {
    return Obx(() => DocumentListTile(
          document: document,
          dense: true,
          isFavorite: interactions.isFavorite(document.id),
          onTap: () => interactions.openFromBrowse(document),
          onLongPress: () => _showFileActionSheet(context, document, interactions),
          highlight: highlight,
          trailingLabel: showFolder ? p.dirname(document.path) : null,
          onToggleFavorite: (_) => interactions.toggleFavoriteFor(document),
          onShare: () => interactions.shareDocument(document),
          onShowInfo: () => showFileInformationSheet(context, document),
          onOpenWith: () => interactions.openWithExternalApp(document),
          onDelete: () async {
            if (await interactions.confirmAndDelete(document)) controller.removeDocument(document.id);
          },
        ));
  }
}

/// Where the folder on screen is; each part jumps there.
class _Breadcrumb extends StatelessWidget {
  final BrowseController controller;
  const _Breadcrumb({required this.controller});

  @override
  Widget build(BuildContext context) {
    final crumbs = controller.breadcrumb;
    return SizedBox(
      height: context.scaledExtent(40),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true, // keeps the current folder in view
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: crumbs.length,
        separatorBuilder: (_, __) => Icon(Icons.chevron_left_rounded, size: 18, color: context.onSurfaceVariant),
        itemBuilder: (context, i) {
          final crumb = crumbs[crumbs.length - 1 - i];
          final isCurrent = i == 0;
          return Center(
            child: TextButton(
              onPressed: isCurrent ? null : () => controller.openFolder(crumb.path),
              child: Text(crumb.name, style: isCurrent ? context.labelLarge : null),
            ),
          );
        },
      ),
    );
  }
}

/// Files' no-access/empty states: a message plus the action that gets the
/// user out of it (UX-17). Always scrollable, so a surrounding
/// [RefreshIndicator] can be pulled.
class _FilesMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _FilesMessage({required this.icon, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Icon(icon, size: 56, color: context.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: context.titleMedium),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Center(child: FilledButton(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}

/// Filters the folder on screen as you type; Enter (or the button) searches
/// it and every subfolder on disk.
class _SearchField extends StatefulWidget {
  final BrowseController controller;
  const _SearchField({super.key, required this.controller});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _text = TextEditingController(text: widget.controller.filter.value);
  Worker? _filterWorker;

  @override
  void initState() {
    super.initState();
    // The field shows the filter in force: a folder change clears it.
    _filterWorker = ever(widget.controller.filter, (String value) {
      if (_text.text != value) _text.text = value;
    });
  }

  @override
  void dispose() {
    _filterWorker?.dispose();
    _text.dispose();
    super.dispose();
  }

  void _searchSubfolders() => widget.controller.searchSubfolders(_text.text);

  @override
  Widget build(BuildContext context) {
    final where = widget.controller.atRoots ? 'all storage' : 'this folder and subfolders';
    return TextField(
      controller: _text,
      onChanged: widget.controller.setFilter,
      onSubmitted: (_) => _searchSubfolders(),
      textInputAction: TextInputAction.search,
      style: context.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.controller.atRoots ? 'Search all storage' : 'Filter, or search subfolders',
        prefixIcon: Icon(Icons.search_rounded, color: context.onSurfaceVariant),
        suffixIcon: IconButton(
          tooltip: 'Search $where',
          icon: const Icon(Icons.manage_search_rounded),
          onPressed: _searchSubfolders,
        ),
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
      height: context.scaledExtent(40),
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
                style: context.labelSmall?.copyWith(
                  color: selected ? context.onPrimary : context.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
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
    // Without this, showModalBottomSheet caps height at 9/16 of the screen
    // by default - this sheet's header + 5 action rows regularly exceeds
    // that on typical phone heights, overflowing instead of just sizing to
    // its (short, fixed) content.
    isScrollControlled: true,
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
                  IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(sheetContext).pop()),
                ],
              ),
            ),
            const Divider(height: 24),
            _SheetAction(
              icon: Icons.menu_book_outlined,
              title: 'Open in Reader',
              onTap: () {
                Navigator.of(sheetContext).pop();
                interactions.openFromBrowse(document);
              },
            ),
            Obx(() => _SheetAction(
                  icon: interactions.isFavorite(document.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                  title: interactions.isFavorite(document.id) ? 'Remove from Favorites' : 'Add to Favorites',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    interactions.toggleFavoriteFor(document);
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
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              title: 'Delete',
              destructive: true,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (await interactions.confirmAndDelete(document)) Get.find<BrowseController>().removeDocument(document.id);
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

  /// Error-coloured, for an action that can't be undone (UX-15).
  final bool destructive;

  const _SheetAction({required this.icon, required this.title, required this.onTap, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color ?? context.onSurfaceVariant),
      title: Text(title, style: context.bodyLarge?.copyWith(color: color)),
      onTap: onTap,
    );
  }
}
