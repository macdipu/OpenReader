import 'dart:async';
import 'dart:io';

import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';

/// A single cell match from [ExcelReaderController.search].
class CellMatch {
  final int row;
  final int column;

  const CellMatch({required this.row, required this.column});
}

/// Drives the Excel reader (BRD §9.12, ODF-015/016, ODF-008 for Excel).
///
/// `excel_plus` is a parser only - no grid widget ships with it (confirmed
/// during `ARCHITECTURE.md`'s research: no adequate ready-made XLSX viewer
/// widget exists on pub.dev). This controller owns the parsed workbook and
/// exposes a plain row/column model; `ExcelReaderView` builds the actual grid
/// on top of it, the same "library gives primitives, OpenDocs builds the
/// widget" pattern `PdfReaderView` used for PDF thumbnails.
///
/// Fixed cell sizing ([cellWidth]/[cellHeight]) is used for v1 rather than
/// honoring each column's/row's actual stored width/height (BRD §9.12 lists
/// "Row height"/"Column width" as Core Features) - a documented simplification
/// (see the Phase 3 task doc), not a silent gap.
class ExcelReaderController extends BaseController {
  static const double cellWidth = 110;
  static const double cellHeight = 36;
  static const double rowHeaderWidth = 48;

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

  Timer? _positionSaveDebounce;

  xls.Sheet? get currentSheet {
    final workbook = _workbook;
    if (workbook == null || sheetNames.isEmpty) return null;
    return workbook.sheets[sheetNames[activeSheetIndex.value]];
  }

  List<List<xls.Data?>> get currentRows => currentSheet?.rows ?? const [];
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
        if (vOffset is num && vOffset > 0) _initialVerticalOffset = vOffset.toDouble();
        final hOffset = position['horizontal_offset'];
        if (hOffset is num && hOffset > 0) _initialHorizontalOffset = hOffset.toDouble();
      });

      final bytes = await File(document.path).readAsBytes();
      final workbook = await xls.Excel.decodeBytesAsync(bytes);
      _workbook = workbook;
      final names = workbook.sheetOrder;
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
    activeSheetIndex.value = index;
    stopSearching();
    _schedulePositionSave();
  }

  void onScrolled() {
    _schedulePositionSave();
  }

  void _schedulePositionSave() {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  Future<void> _savePosition() {
    return _recentRepository.markOpened(
      document.id,
      readingPosition: {
        'sheet_index': activeSheetIndex.value,
        'row': verticalController.hasClients ? (verticalController.offset / cellHeight).floor() : 0,
        'column': horizontalController.hasClients ? (horizontalController.offset / cellWidth).floor() : 0,
        'vertical_offset': verticalController.hasClients ? verticalController.offset : 0.0,
        'horizontal_offset': horizontalController.hasClients ? horizontalController.offset : 0.0,
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
        final text = row[c]?.displayText ?? '';
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
      final target = (cell.row * cellHeight).clamp(0.0, verticalController.position.maxScrollExtent);
      verticalController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
    if (horizontalController.hasClients) {
      final target = (cell.column * cellWidth).clamp(0.0, horizontalController.position.maxScrollExtent);
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
    if (_workbook != null) {
      unawaited(_savePosition());
    }
    verticalController.dispose();
    horizontalController.dispose();
    super.onClose();
  }
}
