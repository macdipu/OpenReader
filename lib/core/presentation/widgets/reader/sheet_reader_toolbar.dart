import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'go_to_cell_dialog.dart';

import '../../controllers/sheet_reader_controller.dart';
import 'reader_toolbar.dart';

/// The Excel and CSV readers' [ReaderBottomBar]: Row x of N (tap to go to a
/// cell) · zoom · freeze header row · full screen.
class SheetReaderToolbar extends StatelessWidget {
  final SheetReaderController controller;

  const SheetReaderToolbar({super.key, required this.controller});

  static final _count = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Rebuilds with the zoom so the buttons enable at their limits.
      controller.zoom.value;
      final sheet = controller.loadedSheet;
      final rows = controller.rowCount.value;
      return ReaderBottomBar(
        children: [
          ReaderPositionButton(
            label: 'Row ${_count.format(controller.topRow.value.clamp(1, rows < 1 ? 1 : rows))} of ${_count.format(rows)}',
            onPressed: sheet == null ? null : () => showGoToCellDialog(context, sheet),
          ),
          ReaderZoomButtons(
            onZoomOut: controller.canZoomOut ? controller.zoomOut : null,
            onZoomIn: controller.canZoomIn ? controller.zoomIn : null,
          ),
          // A sheet whose file froze rows keeps its own.
          if (sheet != null && !sheet.sheetFreezesRows)
            ReaderToolbarButton(
              icon: Icons.table_rows_outlined,
              tooltip: controller.freezeTopRow.value ? 'Unfreeze header row' : 'Freeze header row',
              selected: controller.freezeTopRow.value,
              onPressed: controller.toggleFreezeTopRow,
            ),
          ReaderNightModeButton(on: controller.nightMode.value, onPressed: controller.toggleNightMode),
          ReaderFullscreenButton(onPressed: controller.toggleFullscreen),
        ],
      );
    });
  }
}
