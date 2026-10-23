import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engines/excel/core/excel_plus.dart' as xls;
import 'cell_text.dart';
import 'spreadsheet_controller.dart';

/// A spreadsheet grid: a frozen header row and row-number column, a body
/// that scrolls both axes (synced to the controller's
/// `verticalController`/`horizontalController`), a −/+ zoom pill, search
/// highlights, row/column selection with Count/Sum/Avg and Copy, and a
/// cell's full value on tap. Serves Excel and CSV alike.
class SheetGrid extends StatefulWidget {
  final SpreadsheetController controller;
  final String emptyMessage;

  const SheetGrid({super.key, required this.controller, this.emptyMessage = 'No data to display'});

  @override
  State<SheetGrid> createState() => _SheetGridState();
}

class _SheetGridState extends State<SheetGrid> {
  final _headerHorizontalController = ScrollController();
  final _frozenColumnVerticalController = ScrollController();
  bool _syncingHeader = false;
  bool _syncingFrozenColumn = false;

  /// The row or column picked by tapping its header; null when none.
  final _selection = ValueNotifier<GridSelection?>(null);

  void _toggleSelection(GridSelection selection) =>
      _selection.value = _selection.value == selection ? null : selection;
  late double _zoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreInitialOffsets());
    widget.controller.horizontalController.addListener(_onMainHorizontalScroll);
    widget.controller.verticalController.addListener(_onMainVerticalScroll);
    // Read now, not lazily: the first read used to happen inside the zoom
    // handler, after the change, so the first zoom wasn't anchored.
    _zoom = widget.controller.zoom;
    widget.controller.addListener(_onControllerChanged);
  }

  /// Keeps the same cells in view across a zoom change: offsets scale by
  /// the zoom ratio once the resized grid has laid out (UX-32).
  void _onControllerChanged() {
    if (widget.controller.zoom != _zoom) _onZoomChanged(widget.controller.zoom);
  }

  void _onZoomChanged(double zoom) {
    final ratio = zoom / _zoom;
    _zoom = zoom;
    final vertical = widget.controller.verticalController;
    final horizontal = widget.controller.horizontalController;
    final v = vertical.hasClients ? vertical.offset * ratio : 0.0;
    final h = horizontal.hasClients ? horizontal.offset * ratio : 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (vertical.hasClients) vertical.jumpTo(v.clamp(0.0, vertical.position.maxScrollExtent));
      if (horizontal.hasClients) horizontal.jumpTo(h.clamp(0.0, horizontal.position.maxScrollExtent));
    });
  }

  /// Saved offsets are at 1x zoom (see the readers' `_savePosition`).
  void _restoreInitialOffsets() {
    final controller = widget.controller;
    final zoom = controller.zoom;
    if (controller.verticalController.hasClients && controller.initialVerticalOffset > 0) {
      final max = controller.verticalController.position.maxScrollExtent;
      controller.verticalController.jumpTo((controller.initialVerticalOffset * zoom).clamp(0.0, max));
    }
    if (controller.horizontalController.hasClients && controller.initialHorizontalOffset > 0) {
      final max = controller.horizontalController.position.maxScrollExtent;
      controller.horizontalController.jumpTo((controller.initialHorizontalOffset * zoom).clamp(0.0, max));
    }
  }

  void _onMainHorizontalScroll() {
    if (_syncingHeader) return;
    _syncingHeader = true;
    if (_headerHorizontalController.hasClients) {
      _headerHorizontalController.jumpTo(widget.controller.horizontalController.offset);
    }
    _syncingHeader = false;
    widget.controller.onScrolled();
  }

  void _onMainVerticalScroll() {
    if (_syncingFrozenColumn) return;
    _syncingFrozenColumn = true;
    if (_frozenColumnVerticalController.hasClients) {
      _frozenColumnVerticalController.jumpTo(widget.controller.verticalController.offset);
    }
    _syncingFrozenColumn = false;
    widget.controller.onScrolled();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.horizontalController.removeListener(_onMainHorizontalScroll);
    widget.controller.verticalController.removeListener(_onMainVerticalScroll);
    _headerHorizontalController.dispose();
    _frozenColumnVerticalController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.controller.currentRows;
    final columnCount = widget.controller.columnCount;
    if (rows.isEmpty || columnCount == 0) {
      return _EmptySheet(message: widget.emptyMessage);
    }

    return Stack(
      children: [
        _buildGrid(rows, columnCount),
        Positioned(right: 12, bottom: 12, child: _ZoomControls(controller: widget.controller)),
      ],
    );
  }

  Widget _buildGrid(List<List<xls.Data?>> rows, int columnCount) {
    return ListenableBuilder(listenable: widget.controller, builder: (context, _) {
      final zoom = widget.controller.zoom;
      final metrics = _CellMetrics(zoom);
      return Column(
      children: [
        ValueListenableBuilder<GridSelection?>(
          valueListenable: _selection,
          builder: (context, selection, _) => selection == null
              ? const SizedBox.shrink()
              : _SelectionBar(
                  summary: SelectionSummary.of(rows, columnCount, selection),
                  onClear: () => _selection.value = null,
                ),
        ),
        // Column-letter header row.
        Row(
          children: [
            SizedBox(width: metrics.rowHeaderWidth, height: metrics.height),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerHorizontalController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: ValueListenableBuilder<GridSelection?>(
                  valueListenable: _selection,
                  builder: (context, selection, _) => Row(
                    children: List.generate(
                      columnCount,
                      (c) => _HeaderCell(
                        label: _columnLabel(c),
                        metrics: metrics,
                        selected: selection == GridSelection.column(c),
                        semanticsLabel: 'Column ${_columnLabel(c)}',
                        onTap: () => _toggleSelection(GridSelection.column(c)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Frozen row-number column.
              SizedBox(
                width: metrics.rowHeaderWidth,
                child: ListView.builder(
                  controller: _frozenColumnVerticalController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  itemBuilder: (context, r) => ValueListenableBuilder<GridSelection?>(
                    valueListenable: _selection,
                    builder: (context, selection, _) => _HeaderCell(
                      label: '${r + 1}',
                      metrics: metrics,
                      width: metrics.rowHeaderWidth,
                      selected: selection == GridSelection.row(r),
                      semanticsLabel: 'Row ${r + 1}',
                      onTap: () => _toggleSelection(GridSelection.row(r)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.controller.horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: columnCount * metrics.width,
                    child: ListView.builder(
                      controller: widget.controller.verticalController,
                      itemCount: rows.length,
                      itemBuilder: (context, r) => ValueListenableBuilder<GridSelection?>(
                        valueListenable: _selection,
                        builder: (context, selection, _) => _DataRow(
                          controller: widget.controller,
                          row: rows[r],
                          rowIndex: r,
                          columnCount: columnCount,
                          metrics: metrics,
                          selection: selection,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    });
  }
}

/// Floating −/+ zoom pill over the grid's corner (UX-32) - kept off the app
/// bar, which has no room for two more actions on a phone.
class _ZoomControls extends StatelessWidget {
  final SpreadsheetController controller;

  const _ZoomControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      child: ListenableBuilder(listenable: controller, builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: controller.canZoomOut ? controller.zoomOut : null,
            ),
            Text('${(controller.zoom * 100).round()}%', style: Theme.of(context).textTheme.labelMedium),
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: controller.canZoomIn ? controller.zoomIn : null,
            ),
          ],
        );
      }),
    );
  }
}

/// Cell geometry and text size at a zoom factor (UX-32).
class _CellMetrics {
  _CellMetrics(this.zoom);

  final double zoom;

  double get width => SpreadsheetController.cellWidth * zoom;
  double get height => SpreadsheetController.cellHeight * zoom;
  double get rowHeaderWidth => SpreadsheetController.rowHeaderWidth * zoom;
  double get fontSize => 13 * zoom;
}

/// Full value of a cell, which the grid truncates to one line (UX-32).
Future<void> showCellDetail(BuildContext context, {required String address, required String value}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cell $address', style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5),
              child: SingleChildScrollView(
                child: SelectableText(value.isEmpty ? '(empty)' : value, style: Theme.of(sheetContext).textTheme.bodyLarge),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: value.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: value));
                        Navigator.of(sheetContext).pop();
                      },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _columnLabel(int index) {
  var n = index;
  var label = '';
  do {
    label = String.fromCharCode(65 + n % 26) + label;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return label;
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final _CellMetrics metrics;
  final double? width;
  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _HeaderCell({
    required this.label,
    required this.metrics,
    this.width,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: width ?? metrics.width,
          height: metrics.height,
          alignment: Alignment.center,
          color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12 * metrics.zoom,
              color: selected ? Theme.of(context).colorScheme.onPrimary : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A whole row or column of the grid, picked from its header.
class GridSelection {
  const GridSelection.row(this.index) : isRow = true;
  const GridSelection.column(this.index) : isRow = false;

  final bool isRow;
  final int index;

  bool contains(int row, int column) => isRow ? row == index : column == index;

  @override
  bool operator ==(Object other) => other is GridSelection && other.isRow == isRow && other.index == index;

  @override
  int get hashCode => Object.hash(isRow, index);
}

/// What the selection bar shows: like a spreadsheet's status bar, Sum and
/// Average cover the number cells only.
class SelectionSummary {
  const SelectionSummary({required this.label, required this.values, required this.numbers});

  factory SelectionSummary.of(List<List<xls.Data?>> rows, int columnCount, GridSelection selection) {
    final cells = selection.isRow
        ? [for (var c = 0; c < columnCount; c++) selection.index < rows.length && c < rows[selection.index].length ? rows[selection.index][c] : null]
        : [for (final row in rows) selection.index < row.length ? row[selection.index] : null];
    return SelectionSummary(
      label: selection.isRow ? 'Row ${selection.index + 1}' : 'Column ${_columnLabel(selection.index)}',
      values: [for (final cell in cells) cell?.readerText ?? ''],
      numbers: [for (final cell in cells) if (cell?.numericValue case final n?) n],
    );
  }

  final String label;

  /// Every cell's shown text, in order, blanks included (what Copy copies).
  final List<String> values;
  final List<num> numbers;

  int get count => values.where((v) => v.isNotEmpty).length;
  num get sum => numbers.fold<num>(0, (a, b) => a + b);
  double? get average => numbers.isEmpty ? null : sum / numbers.length;

  /// Trailing blanks dropped, so a column doesn't copy hundreds of empty lines.
  String get copyText {
    var end = values.length;
    while (end > 0 && values[end - 1].isEmpty) {
      end--;
    }
    return values.take(end).join('\n');
  }
}

String _formatNumber(num n) {
  final rounded = n is double ? double.parse(n.toStringAsFixed(4)) : n;
  return rounded == rounded.roundToDouble() && rounded.abs() < 1e15 ? rounded.toInt().toString() : rounded.toString();
}

class _SelectionBar extends StatelessWidget {
  final SelectionSummary summary;
  final VoidCallback onClear;

  const _SelectionBar({required this.summary, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final average = summary.average;
    final details = [
      // Excel's status-bar wording, short enough for a phone.
      'Count ${summary.count}',
      if (summary.numbers.isNotEmpty) 'Sum ${_formatNumber(summary.sum)}',
      if (average != null) 'Avg ${_formatNumber(average)}',
    ].join(' · ');
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: summary.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '  $details'),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
          IconButton(
            tooltip: 'Copy ${summary.label.toLowerCase()}',
            icon: const Icon(Icons.copy_rounded, size: 20),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            onPressed: summary.count == 0
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: summary.copyText));
                    ScaffoldMessenger.maybeOf(context)
                      ?..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text('${summary.label} copied')));
                  },
          ),
          IconButton(
            tooltip: 'Clear selection',
            icon: const Icon(Icons.close_rounded, size: 20),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final SpreadsheetController controller;
  final List<xls.Data?> row;
  final int rowIndex;
  final int columnCount;

  final _CellMetrics metrics;
  final GridSelection? selection;

  const _DataRow({
    required this.controller,
    required this.row,
    required this.rowIndex,
    required this.columnCount,
    required this.metrics,
    this.selection,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final current = controller.matches.isEmpty ? null : controller.matches[controller.currentMatchIndex];
      final matchedColumns = {for (final m in controller.matches) if (m.row == rowIndex) m.column};
      return Row(
        children: List.generate(columnCount, (c) {
          final data = c < row.length ? row[c] : null;
          final highlight = current != null && current.row == rowIndex && current.column == c
              ? _CellHighlight.current
              : matchedColumns.contains(c)
                  ? _CellHighlight.match
                  : selection?.contains(rowIndex, c) ?? false
                      ? _CellHighlight.selected
                      : _CellHighlight.none;
          return _DataCell(
            data: data,
            highlight: highlight,
            metrics: metrics,
            onTap: () => showCellDetail(context, address: '${_columnLabel(c)}${rowIndex + 1}', value: data?.readerText ?? ''),
          );
        }),
      );
    });
  }
}

enum _CellHighlight { none, match, current, selected }

class _DataCell extends StatelessWidget {
  final xls.Data? data;
  final _CellHighlight highlight;
  final _CellMetrics metrics;
  final VoidCallback onTap;

  const _DataCell({required this.data, required this.highlight, required this.metrics, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final backgroundHex = data?.cellStyle?.backgroundColor.colorHex;
    Color? background;
    if (backgroundHex != null && backgroundHex != 'none') {
      try {
        background = Color(int.parse(backgroundHex, radix: 16));
      } catch (_) {
        background = null;
      }
    }
    // Theme colours, not a hard-coded orange (UX-32): the current match
    // stands out, other matches are marked lightly.
    final fill = switch (highlight) {
      _CellHighlight.current => Theme.of(context).colorScheme.tertiaryContainer,
      _CellHighlight.match => Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
      _CellHighlight.selected => Theme.of(context).colorScheme.primaryContainer,
      _CellHighlight.none => background,
    };
    // Readable on the file's own fill colour as well as on the theme surface.
    final textColor = highlight == _CellHighlight.current
        ? Theme.of(context).colorScheme.onTertiaryContainer
        : highlight == _CellHighlight.selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : fill == null || highlight == _CellHighlight.match
            ? Theme.of(context).colorScheme.onSurface
            : (fill.computeLuminance() > 0.5 ? Colors.black87 : Colors.white);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: metrics.width,
        height: metrics.height,
        padding: EdgeInsets.symmetric(horizontal: 6 * metrics.zoom),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
        ),
        child: Text(
          data?.readerText ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: metrics.fontSize,
            fontWeight: (data?.cellStyle?.isBold ?? false) ? FontWeight.bold : FontWeight.normal,
            fontStyle: (data?.cellStyle?.isItalic ?? false) ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}

class _EmptySheet extends StatelessWidget {
  const _EmptySheet({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Icon(Icons.grid_off_rounded, size: 56, color: colors.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }
}
