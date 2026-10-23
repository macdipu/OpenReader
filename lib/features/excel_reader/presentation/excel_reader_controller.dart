import 'dart:async';
import 'dart:io';

import 'package:open_reader_kit/excel.dart' as xls;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/utils/zip_safety_guard.dart';
import '../../../core/presentation/widgets/cell_grid/cell_grid_controller.dart';
import '../../../core/presentation/widgets/cell_grid/cell_match.dart';
import '../../../core/presentation/widgets/cell_grid/cell_text.dart';

export '../../../core/presentation/widgets/cell_grid/cell_match.dart' show CellMatch;

/// Drives the Excel reader (BRD §9.12, ODF-015/016, ODF-008 for Excel).
///
/// `excel_plus` is a parser only - no grid widget ships with it (confirmed
/// during `ARCHITECTURE.md`'s research: no adequate ready-made XLSX viewer
/// widget exists on pub.dev). This controller owns the parsed workbook and
/// exposes a plain row/column model; [CellGrid] (shared with the CSV reader
/// since `FEATURE-OPENREADER-P4`) builds the actual grid on top of it, the same
/// "library gives primitives, OpenReader builds the widget" pattern
/// `PdfReaderView` used for PDF thumbnails.
///
/// Fixed cell sizing ([CellGridController.cellWidth]/[CellGridController.cellHeight])
/// is used for v1 rather than honoring each column's/row's actual stored
/// width/height (BRD §9.12 lists "Row height"/"Column width" as Core
/// Features) - a documented simplification (see the Phase 3 task doc), not a
/// silent gap.
class ExcelReaderController extends BaseController with CellGridZoom implements CellGridController {
  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;

  ExcelReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>();

  xls.Excel? _workbook;

  final sheetNames = <String>[].obs;
  final activeSheetIndex = 0.obs;

  final isSearching = false.obs;
  final searchQuery = ''.obs;
  final matches = <CellMatch>[].obs;
  final currentMatchIndex = (-1).obs;

  final verticalController = ScrollController();
  final horizontalController = ScrollController();

  int _initialSheetIndex = 0;
  double _initialVerticalOffset = 0;
  double _initialHorizontalOffset = 0;
  int get initialSheetIndex => _initialSheetIndex;
  double get initialVerticalOffset => _initialVerticalOffset;
  double get initialHorizontalOffset => _initialHorizontalOffset;

  /// Last-known offsets, refreshed whenever the grid's controllers are
  /// attached. A close saves these: by `onClose` the route's scroll views
  /// have already detached, and reading the controllers then gave 0,
  /// overwriting the saved position (CR-OPENREADER-UX P2r1-review #2).
  double _lastVerticalOffset = 0;
  double _lastHorizontalOffset = 0;

  void _captureOffsets() {
    if (verticalController.hasClients) _lastVerticalOffset = verticalController.offset;
    if (horizontalController.hasClients) _lastHorizontalOffset = horizontalController.offset;
  }

  Timer? _positionSaveDebounce;

  xls.Sheet? get currentSheet {
    final workbook = _workbook;
    if (workbook == null || sheetNames.isEmpty) return null;
    return workbook.sheets[sheetNames[activeSheetIndex.value]];
  }

  @override
  List<List<xls.Data?>> get currentRows => currentSheet?.rows ?? const [];
  @override
  int get columnCount => currentSheet?.maxColumns ?? 0;
  int get frozenRows => currentSheet?.frozenRows ?? 0;
  int get frozenColumns => currentSheet?.frozenColumns ?? 0;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    status.value = StateStatus.loading;
    try {
      final positionResult = await _recentRepository.getPosition(document.id);
      positionResult.fold((_) {}, (position) {
        final sheetIndex = position['sheet_index'];
        if (sheetIndex is int && sheetIndex >= 0) _initialSheetIndex = sheetIndex;
        final vOffset = position['vertical_offset'];
        if (vOffset is num && vOffset > 0) _initialVerticalOffset = _lastVerticalOffset = vOffset.toDouble();
        final hOffset = position['horizontal_offset'];
        if (hOffset is num && hOffset > 0) _initialHorizontalOffset = _lastHorizontalOffset = hOffset.toDouble();
      });

      final bytes = await File(document.path).readAsBytes();
      switch (ZipSafetyGuard.check(bytes)) {
        case ZipSafetyResult.tooLarge:
          status.value = StateStatus.error;
          errorMessage.value = 'This document is too large to render safely on this device.';
          return;
        case ZipSafetyResult.corrupted:
          status.value = StateStatus.error;
          errorMessage.value = 'This document may be damaged or incomplete.';
          return;
        case ZipSafetyResult.safe:
      }

      final workbook = await xls.Excel.decodeBytesAsync(bytes);
      _workbook = workbook;
      // Sheets the author hid stay hidden, as in Excel - unless every sheet
      // is, when showing nothing would be worse.
      final visible = [
        for (final name in workbook.sheetOrder)
          if (workbook.sheets[name]?.visibility == xls.SheetVisibility.visible) name,
      ];
      final names = visible.isEmpty ? workbook.sheetOrder : visible;
      sheetNames.assignAll(names);
      activeSheetIndex.value = _initialSheetIndex < names.length ? _initialSheetIndex : 0;
      status.value = StateStatus.success;
    } catch (e) {
      status.value = StateStatus.error;
      errorMessage.value = 'This document may be damaged or incomplete.';
    }
  }

  void switchSheet(int index) {
    if (index < 0 || index >= sheetNames.length) return;
    if (index != activeSheetIndex.value) {
      // A different sheet gets a new grid, which `CellGrid` jumps to the
      // offsets restored at open - reported as a scroll unless they're 0,
      // when nothing reports at all. Without this reset the cache would then
      // still hold the previous sheet's offsets and save them under this
      // sheet. Re-selecting the current sheet keeps its grid and offsets.
      _lastVerticalOffset = 0;
      _lastHorizontalOffset = 0;
    }
    activeSheetIndex.value = index;
    stopSearching();
    _schedulePositionSave();
  }

  void onScrolled() {
    _captureOffsets();
    _schedulePositionSave();
  }

  void _schedulePositionSave() {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  Future<void> _savePosition() {
    _captureOffsets();
    return _recentRepository.markOpened(
      document.id,
      readingPosition: {
        'sheet_index': activeSheetIndex.value,
        // Stored at 1x zoom (UX-32), so a position survives a zoom change.
        'row': (_lastVerticalOffset / (CellGridController.cellHeight * zoom.value)).floor(),
        'column': (_lastHorizontalOffset / (CellGridController.cellWidth * zoom.value)).floor(),
        'vertical_offset': _lastVerticalOffset / zoom.value,
        'horizontal_offset': _lastHorizontalOffset / zoom.value,
      },
    );
  }

  void startSearching() => isSearching.value = true;

  void stopSearching() {
    isSearching.value = false;
    searchQuery.value = '';
    matches.clear();
    currentMatchIndex.value = -1;
  }

  /// Linear scan over the active sheet's cells (ODF-016). Scoped to the
  /// active sheet only, not the whole workbook - matching how every other
  /// reader's search scopes to "this document", not "everything".
  void search(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      matches.clear();
      currentMatchIndex.value = -1;
      return;
    }
    final lower = query.toLowerCase();
    final found = <CellMatch>[];
    final rows = currentRows;
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        final text = row[c]?.readerText ?? '';
        if (text.toLowerCase().contains(lower)) {
          found.add(CellMatch(row: r, column: c));
        }
      }
    }
    matches.assignAll(found);
    currentMatchIndex.value = found.isEmpty ? -1 : 0;
    if (found.isNotEmpty) jumpToCell(found.first);
  }

  void goToNextMatch() {
    if (matches.isEmpty) return;
    currentMatchIndex.value = (currentMatchIndex.value + 1) % matches.length;
    jumpToCell(matches[currentMatchIndex.value]);
  }

  void goToPrevMatch() {
    if (matches.isEmpty) return;
    currentMatchIndex.value = (currentMatchIndex.value - 1 + matches.length) % matches.length;
    jumpToCell(matches[currentMatchIndex.value]);
  }

  void jumpToCell(CellMatch cell) {
    if (verticalController.hasClients) {
      final target = (cell.row * CellGridController.cellHeight * zoom.value).clamp(0.0, verticalController.position.maxScrollExtent);
      verticalController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
    if (horizontalController.hasClients) {
      final target = (cell.column * CellGridController.cellWidth * zoom.value).clamp(0.0, horizontalController.position.maxScrollExtent);
      horizontalController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
  }

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    _interactions.readerClosedAfter(_workbook != null ? _savePosition() : null);
    verticalController.dispose();
    horizontalController.dispose();
    super.onClose();
  }
}
