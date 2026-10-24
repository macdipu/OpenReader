import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';
import 'package:universal_document_viewer/sheets.dart';

import '../../data/repositories/recent_repository_impl.dart';
import '../../domain/models/document_model.dart';
import '../../domain/repositories/recent_repository.dart';
import '../utils/state_status.dart';
import 'base_controller.dart';
import 'document_interaction_controller.dart';

/// What the Excel and CSV readers share, on top of universal_document_viewer's
/// [SpreadsheetController] (which owns the sheets, search, zoom and
/// scrolling): the saved position (restored on open, saved 2 s after a
/// scroll or sheet switch and once more on close), favourites/share/
/// open-with, the BRD §13 error wording, and observable mirrors of the
/// kit's state for the app bar and sheet tabs.
abstract class SheetReaderController extends BaseController {
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
  final zoom = 1.0.obs;

  List<List<SheetCell?>> get currentRows => _sheet?.currentRows ?? const [];
  int get columnCount => _sheet?.columnCount ?? 0;
  double get initialVerticalOffset => _sheet?.initialVerticalOffset ?? 0;
  double get initialHorizontalOffset => _sheet?.initialHorizontalOffset ?? 0;
  bool get canZoomIn => _sheet?.canZoomIn ?? false;
  bool get canZoomOut => _sheet?.canZoomOut ?? false;

  Timer? _positionSaveDebounce;

  /// Reads the file into [controller] (via `loadXlsx`/`loadCsv`). Throws on
  /// an unreadable file.
  @protected
  Future<void> loadInto(SpreadsheetController controller, File file);

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
      final sheet = _sheet = SpreadsheetController(initialPosition: saved, onPositionChanged: (_) => _scheduleSave())
        ..addListener(_mirror);
      await loadInto(sheet, File(document.path));
      if (isClosed) return;
      switch (sheet.error) {
        case null:
          status.value = StateStatus.success;
        case DocumentLoadError.tooLarge:
          _fail('This document is too large to render safely on this device.');
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
    zoom.value = sheet.zoom;
  }

  void _scheduleSave() {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  Future<void> _savePosition() =>
      _recentRepository.markOpened(document.id, readingPosition: positionToSave(sheet.position));

  void onScrolled() => _sheet?.onScrolled();

  void switchSheet(int index) {
    _sheet?.switchSheet(index);
    isSearching.value = false;
  }

  void zoomIn() => _sheet?.zoomIn();
  void zoomOut() => _sheet?.zoomOut();

  void startSearching() => isSearching.value = true;

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
