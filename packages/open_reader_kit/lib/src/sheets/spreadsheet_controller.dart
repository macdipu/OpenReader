import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../common/reader_contract.dart';
import '../common/text_decoding.dart';
import '../common/zip_safety_guard.dart';
import '../engines/excel/core/excel_plus.dart' as xls;
import 'cell_match.dart';
import 'cell_text.dart';

/// State for [SheetGrid]: a workbook's sheets (or a CSV's single sheet),
/// the sheet on screen, search within it, zoom and scrolling.
///
/// Position is reported through [onPositionChanged] on every scroll and
/// sheet switch as `{sheet_index, row, column, vertical_offset,
/// horizontal_offset}`, offsets at 1x zoom; saving it (and debouncing) is
/// the app's business.
///
/// Cells have a fixed size ([cellWidth] x [cellHeight]) rather than each
/// column's/row's stored width/height - a deliberate simplification.
class SpreadsheetController extends ChangeNotifier {
  SpreadsheetController({ReadingPosition? initialPosition, this.onPositionChanged}) {
    final position = initialPosition ?? const {};
    if (position[PositionKeys.sheetIndex] case final int index when index >= 0) _initialSheetIndex = index;
    if (position[PositionKeys.verticalOffset] case final num v when v > 0) {
      initialVerticalOffset = _lastVerticalOffset = v.toDouble();
    }
    if (position[PositionKeys.horizontalOffset] case final num h when h > 0) {
      initialHorizontalOffset = _lastHorizontalOffset = h.toDouble();
    }
  }

  static const double cellWidth = 110;
  static const double cellHeight = 36;
  static const double rowHeaderWidth = 48;

  static const double minZoom = 0.75;
  static const double maxZoom = 2.0;
  static const double zoomStep = 0.25;

  /// Above this size a CSV is refused rather than parsed in one pass. A
  /// first-pass, adjustable ceiling.
  static const int maxCsvBytes = 20 * 1024 * 1024;

  final ValueChanged<ReadingPosition>? onPositionChanged;

  int _initialSheetIndex = 0;

  /// Where the grid scrolls to once laid out, at 1x zoom.
  double initialVerticalOffset = 0;
  double initialHorizontalOffset = 0;

  final verticalController = ScrollController();
  final horizontalController = ScrollController();

  /// Last-known offsets, refreshed whenever the scroll views are attached.
  /// [position] uses these: once a route's scroll views detach, reading the
  /// controllers would give 0.
  double _lastVerticalOffset = 0;
  double _lastHorizontalOffset = 0;

  bool _disposed = false;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  DocumentLoadError? _error;
  DocumentLoadError? get error => _error;

  xls.Excel? _workbook;
  List<String> _sheetNames = const [];

  /// Visible sheets, in workbook order. A CSV has one.
  List<String> get sheetNames => _sheetNames;

  int _activeSheet = 0;
  int get activeSheetIndex => _activeSheet;

  xls.Sheet? get currentSheet {
    final workbook = _workbook;
    if (workbook == null || _sheetNames.isEmpty) return null;
    return workbook.sheets[_sheetNames[_activeSheet]];
  }

  List<List<xls.Data?>> get currentRows => currentSheet?.rows ?? const [];
  int get columnCount => currentSheet?.maxColumns ?? 0;
  int get frozenRows => currentSheet?.frozenRows ?? 0;
  int get frozenColumns => currentSheet?.frozenColumns ?? 0;

  /// Parses an `.xlsx` after [ZipSafetyGuard] has checked it. Sheets the
  /// author hid stay hidden, as in Excel - unless every sheet is, when
  /// showing nothing would be worse.
  Future<void> loadXlsx(Uint8List bytes) async {
    try {
      switch (ZipSafetyGuard.check(bytes)) {
        case ZipSafetyResult.tooLarge:
          _error = DocumentLoadError.tooLarge;
        case ZipSafetyResult.corrupted:
          _error = DocumentLoadError.corrupted;
        case ZipSafetyResult.safe:
          final workbook = await xls.Excel.decodeBytesAsync(bytes);
          if (_disposed) return;
          final visible = [
            for (final name in workbook.sheetOrder)
              if (workbook.sheets[name]?.visibility == xls.SheetVisibility.visible) name,
          ];
          _setWorkbook(workbook, visible.isEmpty ? workbook.sheetOrder : visible);
      }
    } catch (_) {
      _error = DocumentLoadError.corrupted;
    }
    if (_disposed) return;
    _loaded = true;
    notifyListeners();
  }

  /// Parses CSV bytes (UTF-8, else Latin-1) into one sheet.
  ///
  /// Runs on the calling isolate: `Excel.fromCsv`'s result isn't
  /// isolate-sendable (`Isolate.run` throws "object is unsendable"), unlike
  /// `decodeBytesAsync`'s. [maxCsvBytes] is the only guard against jank on
  /// a very large file.
  void loadCsv(Uint8List bytes) {
    if (bytes.length > maxCsvBytes) {
      _error = DocumentLoadError.tooLarge;
    } else {
      try {
        final workbook = xls.Excel.fromCsv(decodeTextBytes(bytes));
        _setWorkbook(workbook, [workbook.getDefaultSheet()!]);
      } catch (_) {
        _error = DocumentLoadError.corrupted;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// For a caller that refuses a file by its size before reading it (e.g.
  /// a CSV over [maxCsvBytes]): records [DocumentLoadError.tooLarge].
  void rejectAsTooLarge() {
    _error = DocumentLoadError.tooLarge;
    _loaded = true;
    notifyListeners();
  }

  void _setWorkbook(xls.Excel workbook, List<String> names) {
    _workbook = workbook;
    _sheetNames = names;
    _activeSheet = _initialSheetIndex < names.length ? _initialSheetIndex : 0;
  }

  /// Shows another sheet; clears the search, which was for the old one.
  void switchSheet(int index) {
    if (index < 0 || index >= _sheetNames.length) return;
    if (index != _activeSheet) {
      // A different sheet gets a new grid, which jumps to the offsets
      // restored at open - reported as a scroll unless they're 0, when
      // nothing reports at all. Without this reset the cache would still
      // hold the previous sheet's offsets and report them for this sheet.
      // Re-selecting the current sheet keeps its grid and offsets.
      _lastVerticalOffset = 0;
      _lastHorizontalOffset = 0;
    }
    _activeSheet = index;
    _resetSearch();
    notifyListeners();
    onPositionChanged?.call(position);
  }

  double _zoom = 1;

  /// Grid zoom factor; cells, headers and text scale with it.
  double get zoom => _zoom;
  bool get canZoomIn => _zoom < maxZoom;
  bool get canZoomOut => _zoom > minZoom;

  void zoomIn() => _setZoom(_zoom + zoomStep);
  void zoomOut() => _setZoom(_zoom - zoomStep);

  void _setZoom(double value) {
    _zoom = value.clamp(minZoom, maxZoom);
    notifyListeners();
  }

  void _captureOffsets() {
    if (verticalController.hasClients) _lastVerticalOffset = verticalController.offset;
    if (horizontalController.hasClients) _lastHorizontalOffset = horizontalController.offset;
  }

  /// The grid reports every scroll here.
  void onScrolled() {
    _captureOffsets();
    onPositionChanged?.call(position);
  }

  /// Stored at 1x zoom, so a position survives a zoom change.
  ReadingPosition get position {
    _captureOffsets();
    return {
      PositionKeys.sheetIndex: _activeSheet,
      PositionKeys.row: (_lastVerticalOffset / (cellHeight * _zoom)).floor(),
      PositionKeys.column: (_lastHorizontalOffset / (cellWidth * _zoom)).floor(),
      PositionKeys.verticalOffset: _lastVerticalOffset / _zoom,
      PositionKeys.horizontalOffset: _lastHorizontalOffset / _zoom,
    };
  }

  String _query = '';
  String get searchQuery => _query;

  List<CellMatch> _matches = const [];
  List<CellMatch> get matches => _matches;

  int _currentMatch = -1;

  /// Position within [matches], or -1 when there are none.
  int get currentMatchIndex => _currentMatch;

  /// Linear scan of the sheet on screen (not the whole workbook), matching
  /// each cell's shown text in any case; jumps to the first match.
  void search(String query) {
    _query = query;
    final lower = query.toLowerCase();
    final found = <CellMatch>[];
    if (query.isNotEmpty) {
      final rows = currentRows;
      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (var c = 0; c < row.length; c++) {
          if ((row[c]?.readerText ?? '').toLowerCase().contains(lower)) found.add(CellMatch(row: r, column: c));
        }
      }
    }
    _matches = found;
    _currentMatch = found.isEmpty ? -1 : 0;
    notifyListeners();
    if (found.isNotEmpty) jumpToCell(found.first);
  }

  void _resetSearch() {
    _query = '';
    _matches = const [];
    _currentMatch = -1;
  }

  void clearSearch() {
    _resetSearch();
    notifyListeners();
  }

  void nextMatch() {
    if (_matches.isEmpty) return;
    _currentMatch = (_currentMatch + 1) % _matches.length;
    notifyListeners();
    jumpToCell(_matches[_currentMatch]);
  }

  void previousMatch() {
    if (_matches.isEmpty) return;
    _currentMatch = (_currentMatch - 1 + _matches.length) % _matches.length;
    notifyListeners();
    jumpToCell(_matches[_currentMatch]);
  }

  void jumpToCell(CellMatch cell) {
    if (verticalController.hasClients) {
      final target = (cell.row * cellHeight * _zoom).clamp(0.0, verticalController.position.maxScrollExtent);
      verticalController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
    if (horizontalController.hasClients) {
      final target = (cell.column * cellWidth * _zoom).clamp(0.0, horizontalController.position.maxScrollExtent);
      horizontalController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }
}
