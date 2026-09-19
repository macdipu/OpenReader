import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'cell_match.dart';

/// The contract a reader controller must satisfy to drive [CellGrid].
///
/// Extracted from `ExcelReaderController` (`FEATURE-OPENREADER-P3/TASK-011`)
/// so the CSV reader (`FEATURE-OPENREADER-P4`) can reuse the same grid -
/// frozen header row/column, two-axis scroll sync, cell rendering - instead
/// of duplicating it. Both formats parse into the same `excel_plus`
/// `Sheet`/`Data` shape (CSV via `Excel.fromCsv`), so one grid genuinely
/// serves both.
abstract class CellGridController {
  static const double cellWidth = 110;
  static const double cellHeight = 36;
  static const double rowHeaderWidth = 48;

  List<List<xls.Data?>> get currentRows;
  int get columnCount;

  RxList<CellMatch> get matches;
  RxInt get currentMatchIndex;

  ScrollController get verticalController;
  ScrollController get horizontalController;
  double get initialVerticalOffset;
  double get initialHorizontalOffset;

  /// Called whenever either scroll controller moves, so the controller can
  /// debounce a reading-position save.
  void onScrolled();
}
