import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../theme/theme_extensions.dart';
import 'cell_grid_controller.dart';
import '../empty/common_empty_view.dart';

/// A frozen header row + frozen leading columns + a body that scrolls both
/// axes, all synced to the controller's `verticalController`/
/// `horizontalController`. Shared by the Excel and CSV readers - see
/// [CellGridController]'s doc comment for why one widget serves both.
class CellGrid extends StatefulWidget {
  final CellGridController controller;
  final String emptyMessage;

  const CellGrid({super.key, required this.controller, this.emptyMessage = 'No data to display'});

  @override
  State<CellGrid> createState() => _CellGridState();
}

class _CellGridState extends State<CellGrid> {
  final _headerHorizontalController = ScrollController();
  final _frozenColumnVerticalController = ScrollController();
  bool _syncingHeader = false;
  bool _syncingFrozenColumn = false;
  late double _zoom;
  Worker? _zoomWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreInitialOffsets());
    widget.controller.horizontalController.addListener(_onMainHorizontalScroll);
    widget.controller.verticalController.addListener(_onMainVerticalScroll);
    // Read now, not lazily: the first read used to happen inside the zoom
    // handler, after the change, so the first zoom wasn't anchored.
    _zoom = widget.controller.zoom.value;
    _zoomWorker = ever(widget.controller.zoom, _onZoomChanged);
  }

  /// Keeps the same cells in view across a zoom change: offsets scale by
  /// the zoom ratio once the resized grid has laid out (UX-32).
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
    final zoom = controller.zoom.value;
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
    _zoomWorker?.dispose();
    widget.controller.horizontalController.removeListener(_onMainHorizontalScroll);
    widget.controller.verticalController.removeListener(_onMainVerticalScroll);
    _headerHorizontalController.dispose();
    _frozenColumnVerticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.controller.currentRows;
    final columnCount = widget.controller.columnCount;
    if (rows.isEmpty || columnCount == 0) {
      return CommonEmptyView(icon: Icons.grid_off_rounded, message: widget.emptyMessage);
    }

    return Stack(
      children: [
        _buildGrid(rows, columnCount),
        Positioned(right: 12, bottom: 12, child: _ZoomControls(controller: widget.controller)),
      ],
    );
  }

  Widget _buildGrid(List<List<xls.Data?>> rows, int columnCount) {
    return Obx(() {
      final zoom = widget.controller.zoom.value;
      final metrics = _CellMetrics(zoom);
      return Column(
      children: [
        // Column-letter header row.
        Row(
          children: [
            SizedBox(width: metrics.rowHeaderWidth, height: metrics.height),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerHorizontalController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(children: List.generate(columnCount, (c) => _HeaderCell(label: _columnLabel(c), metrics: metrics))),
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
                  itemBuilder: (context, r) => _HeaderCell(label: '${r + 1}', metrics: metrics, width: metrics.rowHeaderWidth),
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
                      itemBuilder: (context, r) => _DataRow(
                        controller: widget.controller,
                        row: rows[r],
                        rowIndex: r,
                        columnCount: columnCount,
                        metrics: metrics,
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
  final CellGridController controller;

  const _ZoomControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceContainerHigh,
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      child: Obx(() {
        controller.zoom.value; // rebuild on zoom changes
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: controller.canZoomOut ? controller.zoomOut : null,
            ),
            Text('${(controller.zoom.value * 100).round()}%', style: context.labelMedium),
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

  double get width => CellGridController.cellWidth * zoom;
  double get height => CellGridController.cellHeight * zoom;
  double get rowHeaderWidth => CellGridController.rowHeaderWidth * zoom;
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
            Text('Cell $address', style: sheetContext.titleMedium),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5),
              child: SingleChildScrollView(
                child: SelectableText(value.isEmpty ? '(empty)' : value, style: sheetContext.bodyLarge),
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

  const _HeaderCell({required this.label, required this.metrics, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? metrics.width,
      height: metrics.height,
      alignment: Alignment.center,
      color: context.surfaceContainer,
      child: Text(label, style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 12 * metrics.zoom)),
    );
  }
}

class _DataRow extends StatelessWidget {
  final CellGridController controller;
  final List<xls.Data?> row;
  final int rowIndex;
  final int columnCount;

  final _CellMetrics metrics;

  const _DataRow({
    required this.controller,
    required this.row,
    required this.rowIndex,
    required this.columnCount,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.matches.isEmpty ? null : controller.matches[controller.currentMatchIndex.value];
      final matchedColumns = {for (final m in controller.matches) if (m.row == rowIndex) m.column};
      return Row(
        children: List.generate(columnCount, (c) {
          final data = c < row.length ? row[c] : null;
          final highlight = current != null && current.row == rowIndex && current.column == c
              ? _CellHighlight.current
              : matchedColumns.contains(c)
                  ? _CellHighlight.match
                  : _CellHighlight.none;
          return _DataCell(
            data: data,
            highlight: highlight,
            metrics: metrics,
            onTap: () => showCellDetail(context, address: '${_columnLabel(c)}${rowIndex + 1}', value: data?.displayText ?? ''),
          );
        }),
      );
    });
  }
}

enum _CellHighlight { none, match, current }

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
      _CellHighlight.current => context.tertiaryContainer,
      _CellHighlight.match => context.secondaryContainer.withValues(alpha: 0.5),
      _CellHighlight.none => background,
    };
    // Readable on the file's own fill colour as well as on the theme surface.
    final textColor = highlight == _CellHighlight.current
        ? context.onTertiaryContainer
        : fill == null || highlight == _CellHighlight.match
            ? context.onSurface
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
          border: Border.all(color: context.outlineVariant, width: 0.5),
        ),
        child: Text(
          data?.displayText ?? '',
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
