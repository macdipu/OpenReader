import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/models/recent_document_model.dart';
import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/file_size_formatter.dart';
import '../../../../core/presentation/widgets/document/document_list_tile.dart';
import '../home_controller.dart';
import '../home_formatters.dart';
import 'hover_surface.dart';

/// Desktop Home's "Recent files": a sortable table (Name, Type, Size, Last opened) of 48 px
/// rows. A click selects a row, a double click opens it; with the table focused Up / Down move
/// the selection, Enter opens and Delete removes from history. Right-click shows the actions.
class RecentFilesTable extends StatefulWidget {
  /// Clock for the double-click check; tests point it at the test binding's fake clock so the
  /// time between two taps does not depend on how busy the machine is.
  @visibleForTesting
  static DateTime Function()? debugNow;

  final List<RecentDocumentModel> rows;
  final String? selectedId;
  final HomeSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<HomeSortColumn> onSort;
  final ValueChanged<RecentDocumentModel> onSelect;
  final ValueChanged<RecentDocumentModel> onOpen;
  final ValueChanged<RecentDocumentModel> onRemove;
  final ValueChanged<int> onMoveSelection;
  final void Function(RecentDocumentModel recent, Offset position) onContextMenu;
  final FocusNode focusNode;

  const RecentFilesTable({
    super.key,
    required this.rows,
    required this.selectedId,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onSelect,
    required this.onOpen,
    required this.onRemove,
    required this.onMoveSelection,
    required this.onContextMenu,
    required this.focusNode,
  });

  static const rowHeight = 48.0;
  static const typeWidth = 112.0;
  static const sizeWidth = 88.0;
  static const openedWidth = 136.0;

  /// Below these table widths the Type, then the Size column is left out.
  static const typeColumnMinWidth = 560.0;
  static const sizeColumnMinWidth = 440.0;

  @override
  State<RecentFilesTable> createState() => _RecentFilesTableState();
}

class _RecentFilesTableState extends State<RecentFilesTable> {
  final _rowKeys = <String, GlobalKey>{};
  String? _lastTapId;
  DateTime? _lastTapAt;
  bool _keyboardFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
  }

  @override
  void didUpdateWidget(RecentFilesTable old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
    }
    // Keep the selected row on screen when the arrow keys move it.
    if (old.selectedId != widget.selectedId && widget.selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _rowKeys[widget.selectedId]?.currentContext;
        if (rowContext != null && rowContext.mounted) {
          // Scrolls only as far as needed, whichever edge the row went past.
          Scrollable.ensureVisible(rowContext, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
          Scrollable.ensureVisible(rowContext, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    super.dispose();
  }

  void _focusChanged() => _updateKeyboardFocus();
  void _highlightChanged(FocusHighlightMode _) => _updateKeyboardFocus();

  void _updateKeyboardFocus() {
    final value =
        widget.focusNode.hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (value != _keyboardFocus && mounted) setState(() => _keyboardFocus = value);
  }

  RecentDocumentModel? get _selected {
    for (final r in widget.rows) {
      if (r.document.id == widget.selectedId) return r;
    }
    return null;
  }

  /// One click selects at once; a second on the same row within the double-tap time opens it.
  void _tap(RecentDocumentModel recent) {
    final now = (RecentFilesTable.debugNow ?? DateTime.now)();
    final id = recent.document.id;
    final isDouble =
        _lastTapId == id && _lastTapAt != null && now.difference(_lastTapAt!) <= kDoubleTapTimeout;
    widget.focusNode.requestFocus();
    if (isDouble) {
      _lastTapId = null;
      _lastTapAt = null;
      widget.onOpen(recent);
    } else {
      _lastTapId = id;
      _lastTapAt = now;
      widget.onSelect(recent);
    }
  }

  @override
  Widget build(BuildContext context) {
    void withSelected(void Function(RecentDocumentModel) action) {
      final selected = _selected;
      if (selected != null) action(selected);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final showType = constraints.maxWidth >= RecentFilesTable.typeColumnMinWidth;
      final showSize = constraints.maxWidth >= RecentFilesTable.sizeColumnMinWidth;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => widget.onMoveSelection(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => widget.onMoveSelection(-1),
          const SingleActivator(LogicalKeyboardKey.enter): () => withSelected(widget.onOpen),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => withSelected(widget.onOpen),
          const SingleActivator(LogicalKeyboardKey.delete): () => withSelected(widget.onRemove),
          const SingleActivator(LogicalKeyboardKey.backspace): () => withSelected(widget.onRemove),
          const SingleActivator(LogicalKeyboardKey.backspace, meta: true): () => withSelected(widget.onRemove),
        },
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: true,
          child: Semantics(
            label: 'Recent files',
            container: true,
            child: Container(
              decoration: BoxDecoration(
                color: context.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(
                    showType: showType,
                    showSize: showSize,
                    sortColumn: widget.sortColumn,
                    ascending: widget.sortAscending,
                    onSort: widget.onSort,
                  ),
                  for (final (index, recent) in widget.rows.indexed) ...[
                    if (index > 0) Divider(height: 1, thickness: 1, color: context.outlineVariant.withValues(alpha: 0.6)),
                    _TableRow(
                      key: _rowKeys.putIfAbsent(recent.document.id, GlobalKey.new),
                      recent: recent,
                      showType: showType,
                      showSize: showSize,
                      selected: recent.document.id == widget.selectedId,
                      keyboardFocus: _keyboardFocus && recent.document.id == widget.selectedId,
                      onTap: () => _tap(recent),
                      onSecondaryTap: (position) {
                        widget.onSelect(recent);
                        widget.onContextMenu(recent, position);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _HeaderRow extends StatelessWidget {
  final bool showType;
  final bool showSize;
  final HomeSortColumn sortColumn;
  final bool ascending;
  final ValueChanged<HomeSortColumn> onSort;

  const _HeaderRow({
    required this.showType,
    required this.showSize,
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell(HomeSortColumn column, String label, {double? width, bool end = false}) {
      final header = _HeaderCell(
        label: label,
        active: sortColumn == column,
        ascending: ascending,
        end: end,
        onTap: () => onSort(column),
      );
      return width == null ? Expanded(child: header) : SizedBox(width: width, child: header);
    }

    return Container(
      color: context.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          cell(HomeSortColumn.name, 'Name'),
          if (showType) cell(HomeSortColumn.type, 'Type', width: RecentFilesTable.typeWidth),
          if (showSize) cell(HomeSortColumn.size, 'Size', width: RecentFilesTable.sizeWidth, end: true),
          cell(HomeSortColumn.lastOpened, 'Last opened', width: RecentFilesTable.openedWidth, end: true),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool active;
  final bool ascending;
  final bool end;
  final VoidCallback onTap;

  const _HeaderCell({
    required this.label,
    required this.active,
    required this.ascending,
    required this.end,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? context.onSurface : context.onSurfaceVariant;
    final order = ascending ? 'ascending' : 'descending';
    return HoverSurface(
      key: ValueKey('home-sort-$label'),
      onTap: onTap,
      semanticLabel: active ? 'Sort by $label, $order' : 'Sort by $label',
      builder: (context, states) => AnimatedContainer(
        duration: homeMotion,
        curve: homeCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: states.hovered ? context.surfaceContainer : null,
          borderRadius: BorderRadius.circular(8),
          border: focusRing(context, states),
        ),
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.labelLarge?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: 4),
            // The sort indicator; a faint one on hover shows the column can sort.
            AnimatedOpacity(
              duration: homeMotion,
              curve: homeCurve,
              opacity: active ? 1 : (states.hovered ? 0.4 : 0),
              child: Icon(
                active && ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                key: active ? ValueKey('home-sort-indicator-$label') : null,
                size: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final RecentDocumentModel recent;
  final bool showType;
  final bool showSize;
  final bool selected;
  final bool keyboardFocus;
  final VoidCallback onTap;
  final ValueChanged<Offset> onSecondaryTap;

  const _TableRow({
    super.key,
    required this.recent,
    required this.showType,
    required this.showSize,
    required this.selected,
    required this.keyboardFocus,
    required this.onTap,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final document = recent.document;
    final secondary = context.bodySmall?.copyWith(color: context.onSurfaceVariant);
    Widget column(double width, String text) => SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: secondary),
          ),
        );

    return HoverSurface(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      focusable: false,
      selected: selected,
      semanticLabel: document.displayName,
      builder: (context, states) => AnimatedContainer(
        key: ValueKey('home-row-${document.id}'),
        duration: homeMotion,
        curve: homeCurve,
        constraints: const BoxConstraints(minHeight: RecentFilesTable.rowHeight),
        decoration: BoxDecoration(
          color: selected
              ? context.secondaryContainer.withValues(alpha: 0.45)
              : (states.hovered ? context.surfaceContainerLow : null),
          border: keyboardFocus ? Border.all(color: context.secondary, width: 2) : null,
        ),
        child: Row(
          children: [
            // The selected row's accent bar.
            AnimatedContainer(
              duration: homeMotion,
              curve: homeCurve,
              width: 3,
              height: RecentFilesTable.rowHeight - 16,
              decoration: BoxDecoration(
                color: selected ? context.secondary : null,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
              ),
            ),
            const SizedBox(width: 13),
            DocumentThumbnail(document: document, size: 28, readingPosition: recent.readingPosition),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.titleSmall),
                    Text(folderName(document.path), maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary),
                  ],
                ),
              ),
            ),
            if (showType)
              SizedBox(
                width: RecentFilesTable.typeWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(document.formatLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary),
                ),
              ),
            if (showSize) column(RecentFilesTable.sizeWidth, formatFileSize(document.sizeBytes)),
            column(RecentFilesTable.openedWidth, formatRelativeTimeLong(recent.lastOpenedAt)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
