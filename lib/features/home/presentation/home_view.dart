import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/relative_time_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../features/file_information/presentation/file_information_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../res/routes/app_routes.dart';
import '../../../services/utilities/storage_access_service.dart';
import 'home_controller.dart';
import '../../../core/presentation/utils/screen_utils.dart';
import '../../../app/shell/app_shell_controller.dart';

/// Home (DESIGN_SPEC.md #08): search, "Browse files", the Continue Reading
/// carousel and the recents list. There's no storage scan
/// (CR-OPENREADER-BROWSE); documents are found in the Browse tab.
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
            tooltip: 'Search documents',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Get.toNamed(AppRoutes.search),
          ),
          // Phones have no navigation rail, which is where "Open file" and
          // Settings live on wider screens (UX-34).
          if (context.isCompactScreen)
            PopupMenuButton<int>(
              tooltip: 'More actions',
              onSelected: (value) => value == 0
                  ? Get.find<AppShellController>().pickAndOpenFile()
                  : Get.toNamed(AppRoutes.settings),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 0, child: Text('Open file')),
                PopupMenuItem(value: 1, child: Text('Settings')),
              ],
            ),
        ],
      ),
      body: Obx(() {
        if (!controller.hasAccess.value) {
          return _PermissionBanner(onRequestAccess: () async {
            final granted = await StorageAccessService.instance.requestOrOpenSettings();
            if (granted) await controller.load();
          });
        }
        if (controller.status.value.isLoading) return const LoadingView();
        if (controller.status.value.isError) {
          return DocumentLoadErrorView(
            message: controller.errorMessage.value ?? 'Unable to load documents.',
            onRetry: controller.retry,
          );
        }

        return LayoutBuilder(builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= _twoPaneMinWidth && controller.recentDocuments.isNotEmpty;
        void choose(RecentDocumentModel r) =>
            twoPane ? controller.select(r.document.id) : interactions.openDocument(r.document);
        final feed = RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _SearchBarStub(onTap: () => Get.toNamed(AppRoutes.search)),
              ),
              // No storage scan (CR-OPENREADER-BROWSE): documents are found
              // in the Browse tab.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: controller.openBrowse,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Browse files'),
                  ),
                ),
              ),
              if (controller.recentDocuments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Wraps rather than pushing "See All" off-screen at large text (UX-31).
                      Expanded(child: Text('Continue Reading', style: context.headlineSmall)),
                      TextButton(onPressed: controller.openHistory, child: const Text('See All')),
                    ],
                  ),
                ),
                SizedBox(
                  // Tall enough for Nocturne's Space Grotesk/JetBrains Mono
                  // line heights, which run taller than Inter (light).
                  height: context.scaledExtent(156),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: controller.recentDocuments.take(HomeController.continueReadingCount).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final recent = controller.recentDocuments[index];
                      return _ContinueReadingCard(
                        recent: recent,
                        onTap: () => choose(recent),
                      );
                    },
                  ),
                ),
                // The rest of the preview - never a document already shown as
                // a card above (UX-12).
                if (controller.recentDocuments.length > HomeController.continueReadingCount)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                    child: Text('Recent Documents', style: context.headlineSmall),
                  ),
                for (final recent in controller.recentDocuments.skip(HomeController.continueReadingCount))
                  Obx(() => _Pickable(
                      selected: twoPane && controller.selectedRecent?.document.id == recent.document.id,
                      onDoubleTap: twoPane ? () => interactions.openDocument(recent.document) : null,
                      child: DocumentListTile(
                        document: recent.document,
                        dense: true,
                        isFavorite: interactions.isFavorite(recent.document.id),
                        onTap: () => choose(recent),
                        onToggleFavorite: (_) => interactions.toggleFavorite(recent.document.id),
                        onShare: () => interactions.shareDocument(recent.document),
                        onShowInfo: () => showFileInformationSheet(context, recent.document),
                        onOpenWith: () => interactions.openWithExternalApp(recent.document),
                        onDelete: () async {
                            if (await interactions.confirmAndDelete(recent.document)) controller.load();
                          },
                        trailingLabel: 'Opened ${formatRelativeTime(recent.lastOpenedAt)}',
                        progress: recent.progress,
                        readingPosition: recent.readingPosition,
                      ))),
              ] else
                _EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No reading history yet',
                  subtitle: 'Documents you open will show up here.',
                  actionLabel: 'Browse Files',
                  onAction: controller.openBrowse,
                ),
            ],
          ),
        );
        if (!twoPane) return feed;
        // Wide windows (desktop, large tablets, an unfolded Fold): the list on the left and
        // the selected document on the right. Click selects; double-click or Open reads it.
        return Row(
          children: [
            SizedBox(width: _listPaneWidth, child: feed),
            VerticalDivider(width: 1, color: context.outlineVariant),
            Expanded(child: Obx(() {
              final selected = controller.selectedRecent;
              if (selected == null) return const SizedBox.shrink();
              return _DocumentDetailsPane(recent: selected, interactions: interactions);
            })),
          ],
        );
        });
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
        height: context.scaledExtent(48),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: context.scaledExtent(220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The page reading resumes on.
                DocumentThumbnail(document: document, size: 44, readingPosition: recent.readingPosition),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${document.category.label} • ${formatFileSize(document.sizeBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (recent.progress case final progress?) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: context.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(context.secondary),
                ),
              ),
              const SizedBox(height: 8),
            ],
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

/// Shared empty-state look for Home's "no documents" / "no reading history"
/// branches - icon + title + subtitle, optional action, instead of bare text.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.surfaceContainerLow, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: context.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(title, style: context.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
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

const double _twoPaneMinWidth = 1000;
const double _listPaneWidth = 440;

/// A list row that can show it is selected and open on double-click, for the
/// two-pane layout. Without [onDoubleTap] it is just the row.
class _Pickable extends StatelessWidget {
  final bool selected;
  final VoidCallback? onDoubleTap;
  final Widget child;

  const _Pickable({required this.selected, required this.onDoubleTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? context.secondaryContainer.withValues(alpha: 0.45) : Colors.transparent,
          border: Border(left: BorderSide(color: selected ? context.secondary : Colors.transparent, width: 3)),
        ),
        child: child,
      ),
    );
  }
}

/// The right-hand pane of Home on wide windows: the selected document's
/// preview, its details and the things you can do with it.
class _DocumentDetailsPane extends StatelessWidget {
  final RecentDocumentModel recent;
  final DocumentInteractionController interactions;

  const _DocumentDetailsPane({required this.recent, required this.interactions});

  @override
  Widget build(BuildContext context) {
    final document = recent.document;
    final accent = document.category.accentColor(context);
    final folder = p.dirname(document.path);
    final dateFormat = DateFormat.yMMMd().add_jm();
    final progress = recent.progress;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: Text(label, style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant))),
              Expanded(child: Text(value, style: context.bodyMedium)),
            ],
          ),
        );

    return Container(
      color: context.surfaceContainerLowest,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.outlineVariant),
                    ),
                    child: DocumentThumbnail(document: document, size: 168, readingPosition: recent.readingPosition),
                  ),
                ),
                const SizedBox(height: 24),
                Text(document.displayName, style: context.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  '${document.category.label} • ${formatFileSize(document.sizeBytes)}',
                  style: context.bodyMedium?.copyWith(color: accent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (progress != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: context.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(context.secondary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${(progress * 100).round()}% read', style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: () => interactions.openDocument(document),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(progress != null ? 'Continue reading' : 'Open'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Obx(() => OutlinedButton.icon(
                          onPressed: () => interactions.toggleFavorite(document.id),
                          icon: Icon(interactions.isFavorite(document.id) ? Icons.star_rounded : Icons.star_outline_rounded),
                          label: Text(interactions.isFavorite(document.id) ? 'Favorited' : 'Favorite'),
                        )),
                    OutlinedButton.icon(
                      onPressed: () => interactions.shareDocument(document),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => interactions.openWithExternalApp(document),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open with'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showFileInformationSheet(context, document),
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('Info'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: context.outlineVariant),
                row('Last opened', dateFormat.format(recent.lastOpenedAt)),
                row('Modified', dateFormat.format(document.modifiedAt)),
                row('Size', formatFileSize(document.sizeBytes)),
                row('Location', folder),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
