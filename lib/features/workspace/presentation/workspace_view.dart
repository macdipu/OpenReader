import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/shell/app_shell_controller.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import 'workspace_controller.dart';
import 'workspace_readers.dart';

/// The content area while documents are open: a tab strip over one or two
/// reader panes. Every tab's reader stays mounted (just moved out of sight
/// when not shown) so its position, zoom, search and PDF engine survive
/// switching tabs.
class WorkspaceView extends StatelessWidget {
  const WorkspaceView({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = Get.find<WorkspaceController>();
    // The tab shortcuts (Ctrl+W, Ctrl+Tab, Ctrl+\) live in the shell, above both the
    // pages and this view, so they work whichever widget last held keyboard focus.
    return Column(
      children: [
        // Full screen in a reader hides the tab strip too.
        Obx(() => workspace.chromeHidden.value
            ? const SizedBox.shrink()
            : Column(children: [
                _TabStrip(workspace: workspace),
                Divider(height: 1, color: context.outlineVariant),
              ])),
        Expanded(child: _Panes(workspace: workspace)),
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  final WorkspaceController workspace;
  const _TabStrip({required this.workspace});

  @override
  Widget build(BuildContext context) {
    final canSplit = MediaQuery.sizeOf(context).width >= WorkspaceController.minSplitWidth;
    return Container(
      height: 46,
      color: context.surfaceContainerLowest,
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final tabs = workspace.tabs.toList();
              final shown = workspace.paneTabs.toList();
              final active = workspace.activeId;
              return ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: tabs.length,
                onReorder: workspace.reorder,
                proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  return ReorderableDragStartListener(
                    key: ValueKey(tab.id),
                    index: index,
                    child: _TabChip(
                      workspace: workspace,
                      tab: tab,
                      active: tab.id == active,
                      shownElsewhere: tab.id != active && shown.contains(tab.id),
                    ),
                  );
                },
              );
            }),
          ),
          if (canSplit)
            Obx(() => IconButton(
                  tooltip: workspace.split.value ? 'Close side-by-side (Ctrl+\\)' : 'Side by side (Ctrl+\\)',
                  isSelected: workspace.split.value,
                  icon: const Icon(Icons.vertical_split_outlined),
                  selectedIcon: const Icon(Icons.vertical_split),
                  onPressed: workspace.toggleSplit,
                )),
          IconButton(
            tooltip: 'Open another document',
            icon: const Icon(Icons.add_rounded),
            onPressed: workspace.hide,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final WorkspaceController workspace;
  final WorkspaceTab tab;
  final bool active;
  final bool shownElsewhere;

  const _TabChip({required this.workspace, required this.tab, required this.active, required this.shownElsewhere});

  Future<void> _menu(BuildContext context, Offset position) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(value: 'left', child: Text('Show in left pane')),
        if (MediaQuery.sizeOf(context).width >= WorkspaceController.minSplitWidth)
          const PopupMenuItem(value: 'copy', child: Text('Split right (same document)')),
        if (MediaQuery.sizeOf(context).width >= WorkspaceController.minSplitWidth)
          const PopupMenuItem(value: 'right', child: Text('Show in right pane')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'close', child: Text('Close tab')),
        if (workspace.tabs.length > 1) const PopupMenuItem(value: 'others', child: Text('Close other tabs')),
      ],
    );
    switch (choice) {
      case 'copy':
        if (!workspace.duplicateToRight(tab.id)) CustomSnackbar.info('Close a tab first (up to ${WorkspaceController.maxTabs} open).');
      case 'left':
        workspace.showInPane(tab.id, 0);
      case 'right':
        workspace.showInPane(tab.id, 1);
      case 'close':
        workspace.close(tab.id);
      case 'others':
        workspace.closeOthers(tab.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = tab.document.category;
    final accent = category.accentColor(context);
    final background = active
        ? context.secondaryContainer
        : (shownElsewhere ? context.secondaryContainer.withValues(alpha: 0.4) : Colors.transparent);

    return Listener(
      // Middle click closes, as in a browser.
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse && event.buttons == kMiddleMouseButton) workspace.close(tab.id);
      },
      child: GestureDetector(
        onSecondaryTapUp: (details) => _menu(context, details.globalPosition),
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: active ? context.secondary : context.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => workspace.show(tab.id),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          category.shortCode,
                          style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800, fontSize: 9.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.bodyMedium?.copyWith(
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? context.secondary : context.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close (Ctrl+W)',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => workspace.close(tab.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panes extends StatelessWidget {
  final WorkspaceController workspace;
  const _Panes({required this.workspace});

  static const _divider = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      return Obx(() {
        final split = workspace.split.value && width >= WorkspaceController.minSplitWidth;
        final ratio = workspace.ratio.value;
        final leftWidth = split ? (width * ratio) - _divider / 2 : width;
        final rightLeft = split ? leftWidth + _divider : width;
        final rightWidth = split ? width - rightLeft : 0.0;
        final paneTabs = workspace.paneTabs.toList();
        final focused = workspace.focusedPane.value;

        Rect rectFor(int pane) =>
            pane == 0 ? Rect.fromLTWH(0, 0, leftWidth, height) : Rect.fromLTWH(rightLeft, 0, rightWidth, height);

        return Stack(
          children: [
            // Every tab's reader stays in the tree, keyed, so it keeps its state; a tab with no
            // pane is parked out of sight and not painted or ticked.
            for (final tab in workspace.tabs)
              () {
                final pane = split ? paneTabs.indexOf(tab.id) : (paneTabs[0] == tab.id ? 0 : -1);
                final rect = pane >= 0 ? rectFor(pane) : Rect.fromLTWH(0, 0, width, height);
                return Positioned.fromRect(
                  key: ValueKey('pane-${tab.id}'),
                  rect: rect,
                  child: Offstage(
                    offstage: pane < 0,
                    child: TickerMode(
                      enabled: pane >= 0,
                      child: _PaneFrame(
                        focused: split && pane == focused,
                        split: split,
                        onFocus: () => workspace.focusPane(pane),
                        // The header is always in the tree (empty when not split) so the reader keeps its
                        // place in it, and its state, when side by side is switched on or off.
                        child: Column(children: [
                          _PaneHeader(workspace: workspace, pane: pane, tab: tab, visible: split && !workspace.chromeHidden.value),
                          Expanded(child: buildTabReader(tab)),
                        ]),
                      ),
                    ),
                  ),
                );
              }(),
            // The right pane is open but has no document yet.
            if (split && paneTabs[1] == null)
              Positioned.fromRect(
                rect: rectFor(1),
                child: _PaneFrame(
                  focused: focused == 1,
                  split: true,
                  onFocus: () => workspace.focusPane(1),
                  child: Column(children: [
                    _PaneHeader(workspace: workspace, pane: 1, tab: null, visible: !workspace.chromeHidden.value),
                    Expanded(child: _EmptyPane(workspace: workspace)),
                  ]),
                ),
              ),
            if (split)
              Positioned(
                left: leftWidth,
                top: 0,
                width: _divider,
                height: height,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) => workspace.setRatio(ratio + details.delta.dx / width),
                    onDoubleTap: () => workspace.setRatio(0.5),
                    child: Center(child: Container(width: 2, color: context.outlineVariant)),
                  ),
                ),
              ),
          ],
        );
      });
    });
  }
}

/// A pane: a click anywhere in it focuses it, and while split the focused one is outlined.
class _PaneFrame extends StatelessWidget {
  final bool focused;
  final bool split;
  final VoidCallback onFocus;
  final Widget child;

  const _PaneFrame({required this.focused, required this.split, required this.onFocus, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onFocus(),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: split ? Border(top: BorderSide(color: focused ? context.secondary : Colors.transparent, width: 2)) : null,
        ),
        child: child,
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  final WorkspaceController workspace;
  const _EmptyPane({required this.workspace});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.surfaceContainerLow,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.vertical_split_outlined, size: 40, color: context.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Open a document here', style: context.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pick a tab above, or open another file to read it side by side.',
            textAlign: TextAlign.center,
            style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Get.find<AppShellController>().pickAndOpenFile(),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Open file'),
          ),
        ],
      ),
    );
  }
}

/// The strip above a pane while side by side: which document it holds, and an (x) that closes the
/// pane (leaves side by side). Collapses to nothing when there is only one pane.
class _PaneHeader extends StatelessWidget {
  final WorkspaceController workspace;
  final int pane;
  final WorkspaceTab? tab;
  final bool visible;

  const _PaneHeader({required this.workspace, required this.pane, required this.tab, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    // The document's name is already in the reader's own app bar just below, so this strip only
    // says which side it is (and which view, for a second view of one document) and holds the
    // controls for the split.
    final side = pane == 0 ? 'Left' : 'Right';
    final copy = tab != null && tab!.copy > 1 ? '  ·  view ${tab!.copy}' : '';
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 12, right: 2),
      color: context.surfaceContainerLowest,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$side$copy',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.labelSmall?.copyWith(color: context.onSurfaceVariant, letterSpacing: 0.4),
            ),
          ),
          IconButton(
            tooltip: 'Swap sides',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: workspace.swapPanes,
          ),
          IconButton(
            tooltip: 'Close this side',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => workspace.closePane(pane),
          ),
        ],
      ),
    );
  }
}
