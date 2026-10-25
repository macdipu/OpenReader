import 'dart:async';

import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/controllers/reader_fullscreen.dart';
import '../../../core/presentation/controllers/reader_night_mode.dart';
import '../../../core/presentation/utils/state_status.dart';
import 'package:universal_document_viewer/word.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';

/// Drives the Word reader (BRD §9.11, ODF-013/014, ODF-008 for Word) on
/// top of universal_document_viewer's [WordController], which checks the
/// file, owns search and scrolling, and restores the saved offset. This
/// adds what's OpenReader's: the saved position (2 s after scrolling and
/// once more on close), favourites/share/open-with via the shared
/// [DocumentInteractionController], and the BRD §13 error wording.
class WordReaderController extends BaseController with ReaderFullscreen, ReaderNightMode {
  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;

  WordReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>() {
    word = WordController(onPositionChanged: _onPositionChanged)..addListener(_onWordChanged);
  }

  late final WordController word;

  double get initialScrollOffset => word.initialScrollOffset;

  final isSearching = false.obs;

  /// Print layout (pages) rather than continuous; mirrors the kit's
  /// [WordController.viewMode] for the toolbar.
  final isPaged = false.obs;

  /// [WordController.zoom] for the toolbar.
  final zoom = 1.0.obs;

  /// Whether the page previews show above the toolbar.
  final showPreviews = false.obs;

  /// Pages exist only in print layout, so showing them switches to it.
  void togglePreviews() {
    if (word.viewMode != WordViewMode.paged) {
      word.viewMode = WordViewMode.paged;
      showPreviews.value = true;
    } else {
      showPreviews.value = !showPreviews.value;
    }
  }

  @override
  void onFullscreenChanged(bool fullscreen) {
    if (fullscreen) showPreviews.value = false;
  }

  bool get canZoomIn => word.canZoomIn;
  bool get canZoomOut => word.canZoomOut;
  void zoomIn() => word.zoomIn();
  void zoomOut() => word.zoomOut();

  void toggleLayout() => word.toggleViewMode();

  /// A load failure swaps the whole body for the error view.
  final hasError = false.obs;

  void _onWordChanged() {
    isPaged.value = word.viewMode == WordViewMode.paged;
    zoom.value = word.zoom;
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
    // A file that can't be read fails as corrupted.
    await word.loadFile(document.path);
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
      Get.back();
    }
  }

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
