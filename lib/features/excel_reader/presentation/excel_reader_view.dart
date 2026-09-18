import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'excel_reader_controller.dart';

/// BRD §9.12 Excel Reader Screen.
///
/// `excel_plus` (the parsing library, see `ExcelReaderController`'s own doc
/// comment) ships no grid widget, so the whole grid below is first-party
/// OpenDocs UI built directly on its parsed cell model.
class ExcelReaderView extends GetView<ExcelReaderController> {
  const ExcelReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReaderAppBar(controller: controller),
      body: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.status.value.isError) return _ReaderErrorView(controller: controller);
        return Column(
          children: [
            Expanded(child: _Grid(controller: controller)),
            _SheetTabBar(controller: controller),
          ],
        );
      }),
    );
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ExcelReaderController controller;

  const _ReaderAppBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Obx(
        () => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: context.titleMedium,
                decoration: const InputDecoration(hintText: 'Search cells', border: InputBorder.none),
                onChanged: controller.search,
              )
            : Text(controller.document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      actions: [
        Obx(
          () => controller.isSearching.value
              ? IconButton(icon: const Icon(Icons.close), onPressed: controller.stopSearching)
              : IconButton(icon: const Icon(Icons.search), onPressed: controller.startSearching),
        ),
        Obx(
          () => IconButton(
            icon: Icon(controller.isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: controller.toggleFavorite,
          ),
        ),
        PopupMenuButton<_ReaderAction>(
          onSelected: (action) => _handle(action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
          ],
        ),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller)),
    );
  }

  void _handle(_ReaderAction action) {
    switch (action) {
      case _ReaderAction.share:
        controller.share();
      case _ReaderAction.openWith:
        controller.openWith();
    }
  }
}

enum _ReaderAction { share, openWith }

class _SearchStatusBar extends StatelessWidget {
  final ExcelReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSearching.value) return const SizedBox.shrink();
      final String label;
      if (controller.searchQuery.value.isEmpty) {
        label = '';
      } else if (controller.matches.isEmpty) {
        // BRD §13.
        label = 'No searchable text found.';
      } else {
        label = '${controller.currentMatchIndex.value + 1} of ${controller.matches.length} result(s)';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.bodySmall)),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: controller.matches.isNotEmpty ? controller.goToPrevMatch : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: controller.matches.isNotEmpty ? controller.goToNextMatch : null,
            ),
          ],
        ),
      );
    });
  }
}

class _SheetTabBar extends StatelessWidget {
  final ExcelReaderController controller;

  const _SheetTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.sheetNames.length <= 1) return const SizedBox.shrink();
      return Container(
        height: 40,
        color: context.surfaceContainer,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: controller.sheetNames.length,
          itemBuilder: (context, index) {
            final selected = index == controller.activeSheetIndex.value;
            return InkWell(
              onTap: () => controller.switchSheet(index),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: selected ? context.primary : Colors.transparent, width: 2)),
                ),
                child: Text(
                  controller.sheetNames[index],
                  style: selected ? context.bodySmall?.copyWith(color: context.primary, fontWeight: FontWeight.bold) : context.bodySmall,
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

/// A frozen header row + frozen leading columns + a body that scrolls both
/// axes, all synced to [ExcelReaderController.verticalController]/
/// [ExcelReaderController.horizontalController].
class _Grid extends StatefulWidget {
  final ExcelReaderController controller;

  const _Grid({required this.controller});

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
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
    final columnCount = widget.controller.currentSheet?.maxColumns ?? 0;
    if (rows.isEmpty || columnCount == 0) {
      return const Center(child: Text('Empty workbook'));
    }

    return Column(
      children: [
        // Column-letter header row.
        Row(
          children: [
            const SizedBox(width: ExcelReaderController.rowHeaderWidth, height: ExcelReaderController.cellHeight),
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
                width: ExcelReaderController.rowHeaderWidth,
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
                    width: columnCount * ExcelReaderController.cellWidth,
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
      width: ExcelReaderController.cellWidth,
      height: ExcelReaderController.cellHeight,
      alignment: Alignment.center,
      color: context.surfaceContainer,
      child: Text(label, style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _DataRow extends StatelessWidget {
  final ExcelReaderController controller;
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
      width: ExcelReaderController.cellWidth,
      height: ExcelReaderController.cellHeight,
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

class _ReaderErrorView extends StatelessWidget {
  final ExcelReaderController controller;

  const _ReaderErrorView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 16),
            Text(controller.errorMessage.value ?? 'This document may be damaged or incomplete.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => Get.back(), child: const Text('Close')),
                const SizedBox(width: 8),
                FilledButton(onPressed: controller.openWith, child: const Text('Try another app')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
