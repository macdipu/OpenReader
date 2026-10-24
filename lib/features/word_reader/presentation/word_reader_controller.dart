import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import 'package:universal_document_viewer/docx.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';

/// Drives the Word reader (BRD §9.11, ODF-013/014, ODF-008 for Word) on
/// top of universal_document_viewer's [WordDocumentController], which checks the
/// file, owns search and scrolling, and restores the saved offset. This
/// adds what's OpenReader's: the saved position (2 s after scrolling and
/// once more on close), favourites/share/open-with via the shared
/// [DocumentInteractionController], and the BRD §13 error wording.
class WordReaderController extends BaseController {
  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;

  WordReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>() {
    word = WordDocumentController(onPositionChanged: _onPositionChanged)..addListener(_onWordChanged);
  }

  late final WordDocumentController word;

  WordSearchController get searchController => word.searchController;
  ScrollController get scrollController => word.scrollController;
  double get initialScrollOffset => word.initialScrollOffset;

  final isSearching = false.obs;

  /// Print layout (pages) rather than continuous; mirrors the kit's
  /// [WordDocumentController.viewMode] for the menu.
  final isPaged = false.obs;

  void toggleLayout() => word.toggleViewMode();

  /// A load failure swaps the whole body for the error view.
  final hasError = false.obs;

  void _onWordChanged() {
    isPaged.value = word.viewMode == WordViewMode.paged;
    switch (word.error) {
      case null:
        break;
      case DocumentLoadError.tooLarge:
        hasError.value = true;
        errorMessage.value ??= 'This document is too large to render safely on this device.';
      default:
        hasError.value = true;
        errorMessage.value ??= 'This document may be damaged or incomplete.';
    }
  }

  ReadingPosition? _lastKnownPosition;
  Timer? _positionSaveDebounce;

  /// Set by [onClose]: the initial load may still be awaiting the saved
  /// position or the file, and mustn't then use the disposed [word].
  bool _closed = false;

  @override
  void onInit() {
    super.onInit();
    _loadInitialPosition();
  }

  Future<void> _loadInitialPosition() async {
    status.value = StateStatus.loading;
    final result = await _recentRepository.getPosition(document.id);
    if (_closed) return;
    result.fold((_) {}, word.restore);
    isPaged.value = word.viewMode == WordViewMode.paged;
    try {
      final bytes = await File(document.path).readAsBytes();
      if (_closed) return;
      await word.load(bytes);
    } catch (_) {
      if (_closed) return;
      word.rejectAsCorrupted();
    }
    if (_closed) return;
    status.value = StateStatus.success;
  }

  /// Called as the document scrolls (through the kit) with
  /// `{scroll_offset, view_mode}`, debounced the same way
  /// `PdfReaderController` debounces per-page saves.
  void _onPositionChanged(ReadingPosition position) {
    _lastKnownPosition = position;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(position));
  }

  Future<void> _savePosition(ReadingPosition position) =>
      _recentRepository.markOpened(document.id, readingPosition: position);

  void startSearching() => isSearching.value = true;

  void stopSearching() {
    isSearching.value = false;
    word.clearSearch();
  }

  void onSearchQueryChanged(String query) => word.search(query);

  void goToNextMatch() => word.nextMatch();
  void goToPrevMatch() => word.previousMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _closed = true;
    _positionSaveDebounce?.cancel();
    final last = _lastKnownPosition;
    _interactions.readerClosedAfter(last == null ? null : _savePosition(last));
    word.dispose();
    super.onClose();
  }
}
