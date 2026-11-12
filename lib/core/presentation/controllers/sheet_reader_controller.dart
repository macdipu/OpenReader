import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';
import 'package:universal_document_viewer/spreadsheet.dart';

import '../../data/repositories/recent_repository_impl.dart';
import '../../domain/models/document_model.dart';
import '../../domain/repositories/recent_repository.dart';
import '../utils/state_status.dart';
import 'base_controller.dart';
import 'document_interaction_controller.dart';
import 'reader_fullscreen.dart';
import 'reader_night_mode.dart';

/// What the Excel and CSV readers share, on top of universal_document_viewer's
/// [SpreadsheetController] (which owns the sheets, search, zoom and
/// scrolling): the saved position (restored on open, saved 2 s after a
/// scroll or sheet switch and once more on close), favourites/share/
/// open-with, the BRD §13 error wording, and observable mirrors of the
/// kit's state for the app bar and sheet tabs.
abstract class SheetReaderController extends BaseController with ReaderFullscreen, ReaderNightMode {
  SheetReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>();

  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;

  SpreadsheetController? _sheet;

  /// Created in [onInit] with the saved position.
  SpreadsheetController get sheet => _sheet!;

  /// The sheet once it's on screen, for the reader menu's Go to and Freeze
  /// header row; null while loading or after a failure.
  SpreadsheetController? get loadedSheet => status.value == StateStatus.success ? _sheet : null;

  final isSearching = false.obs;

  // Mirrors of the kit's state, for Obx widgets and tests.
  final sheetNames = <String>[].obs;
  final activeSheetIndex = 0.obs;
  final searchQuery = ''.obs;
  final matches = <CellMatch>[].obs;
  final currentMatchIndex = (-1).obs;

  /// Find options (match case, whole cell, formulas, all sheets).
  final searchOptions = const SheetSearchOptions().obs;

  /// A big workbook is searched in slices; true until it is done.
  final searchInProgress = false.obs;

  /// The options a new search starts with; Excel searches every sheet.
  @protected
  SheetSearchOptions get defaultSearchOptions => const SheetSearchOptions();

  /// The sheet name of the current match when it may be on another sheet;
  /// null otherwise.
  String? get currentMatchSheetName {
    final index = currentMatchIndex.value;
    if (!searchOptions.value.allSheets || sheetNames.length < 2 || index < 0 || index >= matches.length) return null;
    final sheet = matches[index].sheet;
    return sheet == null || sheet >= sheetNames.length ? null : sheetNames[sheet];
  }

  void setSearchOptions(SheetSearchOptions options) => _sheet?.searchOptions = options;
  final zoom = 1.0.obs;
  final freezeTopRow = false.obs;

  /// Sheets the author hid, which have no tab (CR-EXCEL-READER-AUDIT S4).
  final hiddenSheetNames = <String>[].obs;

  /// What the sheet on screen holds that the reader doesn't draw.
  final unshownContent = <UnshownContent>{}.obs;

  /// Sheets whose "not shown" notice was closed, so it stays closed.
  final _noticeDismissed = <int>{}.obs;

  /// Whether to show the "not shown" notice for the sheet on screen.
  bool get showUnshownNotice =>
      unshownContent.isNotEmpty && !_noticeDismissed.contains(activeSheetIndex.value);

  void dismissUnshownNotice() => _noticeDismissed.add(activeSheetIndex.value);

  /// The (1-based) sheet row at the top of the grid, and how many rows the
  /// sheet has, for the toolbar.
  final topRow = 1.obs;
  final rowCount = 0.obs;

  List<List<SheetCell?>> get currentRows => _sheet?.currentRows ?? const [];
  int get columnCount => _sheet?.columnCount ?? 0;
  double get initialVerticalOffset => _sheet?.initialVerticalOffset ?? 0;
  double get initialHorizontalOffset => _sheet?.initialHorizontalOffset ?? 0;
  bool get canZoomIn => _sheet?.canZoomIn ?? false;
  bool get canZoomOut => _sheet?.canZoomOut ?? false;

  Timer? _positionSaveDebounce;

  /// What the file is: an Excel workbook or CSV, whatever its name says.
  @protected
  DocumentFormat get format;

  /// What [SpreadsheetController.position] is saved as; a single-sheet
  /// format can drop the sheet index.
  @protected
  ReadingPosition positionToSave(ReadingPosition position) => position;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    status.value = StateStatus.loading;
    try {
      ReadingPosition? saved;
      final positionResult = await _recentRepository.getPosition(document.id);
      positionResult.fold((_) {}, (position) => saved = position);
      if (isClosed) return;
      final sheet = _sheet = SpreadsheetController(
        initialPosition: saved,
        onPositionChanged: _onPositionChanged,
        format: format,
      )
        ..searchOptions = defaultSearchOptions
        ..addListener(_mirror);
      // Refuses an oversized file before reading it.
      await sheet.loadFile(document.path);
      if (isClosed) return;
      switch (sheet.error) {
        case null:
          status.value = StateStatus.success;
        case DocumentLoadError.tooLarge:
          _fail('This document is too large to render safely on this device.');
        case DocumentLoadError.passwordRequired:
          _fail('This workbook is password protected. OpenReader can\'t open protected workbooks yet; try another app.');
        default:
          _fail('This document may be damaged or incomplete.');
      }
    } catch (_) {
      _fail('This document may be damaged or incomplete.');
    }
  }

  void _fail(String message) {
    status.value = StateStatus.error;
    errorMessage.value = message;
  }

  void _mirror() {
    final sheet = _sheet!;
    if (!listEquals(sheetNames, sheet.sheetNames)) sheetNames.assignAll(sheet.sheetNames);
    activeSheetIndex.value = sheet.activeSheetIndex;
    searchQuery.value = sheet.searchQuery;
    if (!listEquals(matches, sheet.matches)) matches.assignAll(sheet.matches);
    currentMatchIndex.value = sheet.currentMatchIndex;
    searchOptions.value = sheet.searchOptions;
    searchInProgress.value = sheet.isSearching;
    zoom.value = sheet.zoom;
    freezeTopRow.value = sheet.freezeTopRow;
    rowCount.value = sheet.currentRows.length;
    if (!listEquals(hiddenSheetNames, sheet.hiddenSheetNames)) hiddenSheetNames.assignAll(sheet.hiddenSheetNames);
    final unshown = sheet.currentSheet?.unshown ?? const <UnshownContent>{};
    if (!setEquals(unshownContent, unshown)) {
      unshownContent
        ..clear()
        ..addAll(unshown);
    }
  }

  void _onPositionChanged(ReadingPosition position) {
    if (position[PositionKeys.row] case final int row) topRow.value = row + 1;
    _scheduleSave();
  }

  void _scheduleSave() {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  Future<void> _savePosition() =>
      _recentRepository.markOpened(document.id, readingPosition: positionToSave(sheet.position));


  /// A tab tap: the search ends, even one of every sheet (going to a
  /// match on another sheet doesn't come through here).
  void switchSheet(int index) {
    _sheet?.switchSheet(index);
    if (isSearching.value || searchQuery.value.isNotEmpty) stopSearching();
  }

  void zoomIn() => _sheet?.zoomIn();
  void zoomOut() => _sheet?.zoomOut();

  void toggleFreezeTopRow() {
    if (loadedSheet case final sheet?) sheet.freezeTopRow = !sheet.freezeTopRow;
  }

  void startSearching() {
    setFullscreen(false);
    isSearching.value = true;
  }

  /// Esc: leave full screen, then close search, then the reader.
  void escape() {
    if (isFullscreen.value) {
      setFullscreen(false);
    } else if (isSearching.value) {
      stopSearching();
    } else {
      escapeReader();
    }
  }

  void stopSearching() {
    isSearching.value = false;
    _sheet?.clearSearch();
  }

  void search(String query) => _sheet?.search(query);
  void goToNextMatch() => _sheet?.nextMatch();
  void goToPrevMatch() => _sheet?.previousMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    final loaded = _sheet?.sheetNames.isNotEmpty ?? false;
    _interactions.readerClosedAfter(loaded ? _savePosition() : null);
    _sheet?.dispose();
    super.onClose();
  }
}
