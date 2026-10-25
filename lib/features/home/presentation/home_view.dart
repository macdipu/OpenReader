import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

        return RefreshIndicator(
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
                        onTap: () => interactions.openDocument(recent.document),
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
                  Obx(() => DocumentListTile(
                        document: recent.document,
                        dense: true,
                        isFavorite: interactions.isFavorite(recent.document.id),
                        onTap: () => interactions.openDocument(recent.document),
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
                      )),
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
