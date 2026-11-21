import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/utils/storage_access_flow.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../res/routes/app_routes.dart';
import '../../../services/utilities/storage_access_service.dart';
import 'home_controller.dart';
import 'widgets/continue_reading_row.dart';
import 'widgets/home_document_actions.dart';
import 'widgets/home_inspector.dart';
import 'widgets/home_states.dart';
import 'widgets/home_toolbar.dart';
import 'widgets/hover_surface.dart';
import 'widgets/pane_resize_handle.dart';
import 'widgets/recent_files_table.dart';

/// Desktop (and wide-tablet) Home: a split-panel workspace. Beside the app sidebar, the main
/// pane has its own toolbar (title, search, details toggle) and scrolls Continue reading and the
/// Recent files table; the inspector on the right shows the selected file. Below
/// [overlayBreakpoint] window width the inspector is a drawer over the main pane instead.
class HomeDesktopView extends GetView<HomeController> {
  const HomeDesktopView({super.key});

  /// Window width below which the inspector is an overlay drawer rather than a docked pane.
  static const overlayBreakpoint = 1280.0;

  @override
  Widget build(BuildContext context) {
    final interactions = Get.find<DocumentInteractionController>();
    final overlay = MediaQuery.sizeOf(context).width < overlayBreakpoint;

    return Scaffold(
      key: const ValueKey('home-desktop'),
      body: Obx(() {
        final status = controller.status.value;
        final hasRecents = controller.hasAccess.value &&
            !status.isLoading &&
            !status.isError &&
            controller.recentDocuments.isNotEmpty;
        final inspectorShown =
            hasRecents && (overlay ? controller.inspectorOverlayOpen.value : controller.inspectorVisible.value);
        void toggle() => controller.toggleInspector(overlay: overlay);

        final toolbar = HomeToolbar(
          onSearch: () => Get.toNamed(AppRoutes.search),
          onToggleInspector: hasRecents ? toggle : null,
          inspectorShown: inspectorShown,
        );
        final content = _content(context, interactions, overlay: overlay);

        final Widget body;
        if (!hasRecents) {
          body = Column(children: [toolbar, Expanded(child: content)]);
        } else if (overlay) {
          // The drawer sits under the toolbar, so its toggle stays in reach.
          body = Column(children: [
            toolbar,
            Expanded(
              child: Stack(children: [
                Positioned.fill(child: content),
                Positioned.fill(child: _overlayInspector(context, interactions, open: inspectorShown)),
              ]),
            ),
          ]);
        } else {
          body = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Column(children: [toolbar, Expanded(child: content)])),
            _dockedInspector(interactions, shown: inspectorShown),
          ]);
        }

        return CallbackShortcuts(
          bindings: {
            if (hasRecents) ...{
              const SingleActivator(LogicalKeyboardKey.keyI, meta: true): toggle,
              const SingleActivator(LogicalKeyboardKey.keyI, control: true): toggle,
            },
            if (overlay && inspectorShown)
              const SingleActivator(LogicalKeyboardKey.escape): () => controller.inspectorOverlayOpen.value = false,
          },
          child: body,
        );
      }),
    );
  }

  Widget _content(BuildContext context, DocumentInteractionController interactions, {required bool overlay}) {
    final status = controller.status.value;
    if (!controller.hasAccess.value) {
      return HomePermissionBanner(
        onRequestAccess: () => requestStorageAccessFlow(
          access: StorageAccessService.instance,
          onGranted: controller.load,
          isClosed: () => controller.isClosed,
        ),
      );
    }
    if (status.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [_SectionHeader('Recent files'), SizedBox(height: 12), HomeSkeletonRows()],
      );
    }
    if (status.isError) {
      return DocumentLoadErrorView(
        message: controller.errorMessage.value ?? 'Unable to load documents.',
        onRetry: controller.retry,
      );
    }
    if (controller.recentDocuments.isEmpty) {
      return HomeDesktopEmptyState(onOpenFile: controller.pickAndOpenFile, onBrowse: controller.openBrowse);
    }

    void open(RecentDocumentModel recent) => unawaited(interactions.openDocument(recent.document));
    void menu(RecentDocumentModel recent, Offset position) => unawaited(showHomeDocumentMenu(
          context,
          position: position,
          recent: recent,
          interactions: interactions,
          controller: controller,
        ));
    final continueReading = controller.continueReading;

    return ListView(
      key: const ValueKey('home-main-scroll'),
      padding: const EdgeInsets.all(24),
      children: [
        if (continueReading.isNotEmpty) ...[
          const _SectionHeader('Continue reading'),
          const SizedBox(height: 12),
          ContinueReadingRow(recents: continueReading, onOpen: open, onContextMenu: menu),
          const SizedBox(height: 24),
        ],
        _SectionHeader(
          'Recent files',
          trailing: controller.hasMoreRecents
              ? TextButton(onPressed: controller.openHistory, child: const Text('See all'))
              : null,
        ),
        const SizedBox(height: 12),
        RecentFilesTable(
          rows: controller.tableRows,
          selectedId: controller.selectedId.value,
          sortColumn: controller.sortColumn.value,
          sortAscending: controller.sortAscending.value,
          focusNode: controller.listFocus,
          onSort: controller.sortBy,
          onSelect: (recent) {
            controller.select(recent.document.id);
            if (overlay) controller.inspectorOverlayOpen.value = true;
          },
          onOpen: open,
          onRemove: (recent) => unawaited(confirmRemoveFromHistory(controller, recent)),
          onMoveSelection: controller.moveSelection,
          onContextMenu: menu,
        ),
      ],
    );
  }

  Widget _dockedInspector(DocumentInteractionController interactions, {required bool shown}) {
    return AnimatedSwitcher(
      duration: homeMotion,
      switchInCurve: homeCurve,
      switchOutCurve: homeCurve,
      transitionBuilder: (child, animation) =>
          SizeTransition(sizeFactor: animation, axis: Axis.horizontal, alignment: Alignment.centerLeft, child: child),
      // Passthrough keeps the full pane height, so the inspector runs from the top to the bottom
      // of the window instead of floating as a box in the middle.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      child: shown
          ? Row(
              key: const ValueKey('home-inspector-docked'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaneResizeHandle(
                  width: controller.inspectorWidth.value,
                  minWidth: HomeController.inspectorMinWidth,
                  maxWidth: HomeController.inspectorMaxWidth,
                  onResize: controller.resizeInspector,
                  onReset: controller.resetInspectorWidth,
                ),
                SizedBox(
                  width: controller.inspectorWidth.value,
                  child: HomeInspector(controller: controller, interactions: interactions),
                ),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('home-inspector-hidden')),
    );
  }

  Widget _overlayInspector(BuildContext context, DocumentInteractionController interactions, {required bool open}) {
    return AnimatedSwitcher(
      duration: homeMotion,
      switchInCurve: homeCurve,
      switchOutCurve: homeCurve,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
        child: child,
      ),
      child: open
          ? Align(
              key: const ValueKey('home-inspector-overlay'),
              alignment: Alignment.centerRight,
              child: Material(
                elevation: 8,
                shadowColor: context.shadow,
                color: context.surfaceContainerLowest,
                child: SizedBox(
                  width: controller.inspectorWidth.value,
                  height: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: context.outlineVariant))),
                    child: HomeInspector(
                      controller: controller,
                      interactions: interactions,
                      onClose: () => controller.inspectorOverlayOpen.value = false,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('home-inspector-closed')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: context.headlineSmall?.copyWith(color: context.onSurface))),
        if (trailing != null) trailing!,
      ],
    );
  }
}
