import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/utils/text_decoding.dart';
import '../../../core/presentation/widgets/cell_grid/cell_grid_controller.dart';
import '../../../core/presentation/widgets/cell_grid/cell_match.dart';

export '../../../core/presentation/widgets/cell_grid/cell_match.dart' show CellMatch;

/// Drives the CSV reader (BRD §9.15, ODF-020, ODF-008 for CSV).
///
/// Parses via `excel_plus`'s `Excel.fromCsv` (already a dependency since
/// `FEATURE-OPENDOCS-P3`) rather than a dedicated CSV library or a hand-rolled
/// parser - it already handles BRD's hardest CSV corner cases (quoted commas,
/// multi-line quoted values) as part of its own tested surface
/// (`FEATURE-OPENDOCS-P4/ARCHITECTURE.md` Alternatives Considered).
///
/// `Excel.fromCsv` has no isolate-friendly entry point (confirmed by reading
/// `excel_plus`'s source - unlike its `.xlsx` path's `decodeBytesAsync`), so
/// this controller wraps the parse call in its own `Isolate.run` rather than
/// assuming the library keeps the UI thread responsive for a large CSV
/// (`ARCHITECTURE.md` Risk 2). `Excel.decodeBytesAsync`'s own implementation
/// confirms `Excel` objects are safe to hand back across an isolate boundary
/// this way (via `Isolate.exit`, not a deep copy).
///
/// Reuses the same [CellGridController]/`CellGrid` the Excel reader uses
/// (`FEATURE-OPENDOCS-P3/TASK-011`, extracted to be shared in this phase) -
/// CSV has one implicit sheet, so there is no sheet-tab bar, but the row/
/// column grid itself is identical.
class CsvReaderController extends BaseController implements CellGridController {
  /// Same posture as `TextReaderController.maxBytes`: a first-pass,
  /// adjustable ceiling, not a BRD-specified number.
  static const int maxBytes = 20 * 1024 * 1024;

  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;

  CsvReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>();

  xls.Sheet? _sheet;

  final isSearching = false.obs;
  final searchQuery = ''.obs;
  @override
  final matches = <CellMatch>[].obs;
  @override
  final currentMatchIndex = (-1).obs;

  @override
  final verticalController = ScrollController();
  @override
  final horizontalController = ScrollController();

  double _initialVerticalOffset = 0;
  double _initialHorizontalOffset = 0;
  @override
  double get initialVerticalOffset => _initialVerticalOffset;
  @override
  double get initialHorizontalOffset => _initialHorizontalOffset;

  Timer? _positionSaveDebounce;

  @override
  List<List<xls.Data?>> get currentRows => _sheet?.rows ?? const [];
  @override
  int get columnCount => _sheet?.maxColumns ?? 0;

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
        final vOffset = position['vertical_offset'];
        if (vOffset is num && vOffset > 0) _initialVerticalOffset = vOffset.toDouble();
        final hOffset = position['horizontal_offset'];
        if (hOffset is num && hOffset > 0) _initialHorizontalOffset = hOffset.toDouble();
      });

      final file = File(document.path);
      final length = await file.length();
      if (length > maxBytes) {
        status.value = StateStatus.error;
        errorMessage.value = 'This document is too large to render safely on this device.';
        return;
      }

      final bytes = await file.readAsBytes();
      final csvText = decodeTextBytes(bytes);
      final workbook = await Isolate.run(() => xls.Excel.fromCsv(csvText));
      _sheet = workbook.sheets[workbook.getDefaultSheet()];
      status.value = StateStatus.success;
    } catch (e) {
      status.value = StateStatus.error;
      errorMessage.value = 'This document may be damaged or incomplete.';
    }
  }

  void onScrolled() {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  Future<void> _savePosition() {
    return _recentRepository.markOpened(
      document.id,
      readingPosition: {
        'row': verticalController.hasClients ? (verticalController.offset / CellGridController.cellHeight).floor() : 0,
        'column': horizontalController.hasClients ? (horizontalController.offset / CellGridController.cellWidth).floor() : 0,
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

  /// Linear scan over the parsed rows (ODF-020's search feature) - the same
  /// shape as the Excel reader's cell search, since it operates on the
  /// identical `Sheet`/`Data` model.
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
      final target = (cell.row * CellGridController.cellHeight).clamp(0.0, verticalController.position.maxScrollExtent);
      verticalController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
    if (horizontalController.hasClients) {
      final target = (cell.column * CellGridController.cellWidth).clamp(0.0, horizontalController.position.maxScrollExtent);
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
    if (_sheet != null) {
      unawaited(_savePosition());
    }
    verticalController.dispose();
    horizontalController.dispose();
    super.onClose();
  }
}
