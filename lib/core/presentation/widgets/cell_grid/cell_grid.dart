import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/theme_extensions.dart';
import 'cell_grid_controller.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreInitialOffsets());
    widget.controller.horizontalController.addListener(_onMainHorizontalScroll);
    widget.controller.verticalController.addListener(_onMainVerticalScroll);
  }

  void _restoreInitialOffsets() {
    final controller = widget.controller;
    if (controller.verticalController.hasClients && controller.initialVerticalOffset > 0) {
      final max = controller.verticalController.position.maxScrollExtent;
      controller.verticalController.jumpTo(controller.initialVerticalOffset.clamp(0.0, max));
    }
    if (controller.horizontalController.hasClients && controller.initialHorizontalOffset > 0) {
      final max = controller.horizontalController.position.maxScrollExtent;
      controller.horizontalController.jumpTo(controller.initialHorizontalOffset.clamp(0.0, max));
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
      return Center(child: Text(widget.emptyMessage));
    }

    return Column(
      children: [
        // Column-letter header row.
        Row(
          children: [
            const SizedBox(width: CellGridController.rowHeaderWidth, height: CellGridController.cellHeight),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerHorizontalController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(children: List.generate(columnCount, (c) => _HeaderCell(label: _columnLabel(c)))),
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
                width: CellGridController.rowHeaderWidth,
                child: ListView.builder(
                  controller: _frozenColumnVerticalController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  itemBuilder: (context, r) => _HeaderCell(label: '${r + 1}'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.controller.horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: columnCount * CellGridController.cellWidth,
                    child: ListView.builder(
                      controller: widget.controller.verticalController,
                      itemCount: rows.length,
                      itemBuilder: (context, r) => _DataRow(controller: widget.controller, row: rows[r], rowIndex: r, columnCount: columnCount),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CellGridController.cellWidth,
      height: CellGridController.cellHeight,
      alignment: Alignment.center,
      color: context.surfaceContainer,
      child: Text(label, style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _DataRow extends StatelessWidget {
  final CellGridController controller;
  final List<xls.Data?> row;
  final int rowIndex;
  final int columnCount;

  const _DataRow({required this.controller, required this.row, required this.rowIndex, required this.columnCount});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final match = controller.matches.isEmpty ? null : controller.matches[controller.currentMatchIndex.value];
      return Row(
        children: List.generate(columnCount, (c) {
          final data = c < row.length ? row[c] : null;
          final isCurrentMatch = match != null && match.row == rowIndex && match.column == c;
          return _DataCell(data: data, highlighted: isCurrentMatch);
        }),
      );
    });
  }
}

class _DataCell extends StatelessWidget {
  final xls.Data? data;
  final bool highlighted;

  const _DataCell({required this.data, required this.highlighted});

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
    return Container(
      width: CellGridController.cellWidth,
      height: CellGridController.cellHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: highlighted ? Colors.orange.withValues(alpha: 0.4) : background,
        border: Border.all(color: context.outlineVariant, width: 0.5),
      ),
      child: Text(
        data?.displayText ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: (data?.cellStyle?.isBold ?? false) ? FontWeight.bold : FontWeight.normal,
          fontStyle: (data?.cellStyle?.isItalic ?? false) ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}
