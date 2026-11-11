import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/controllers/reader_fullscreen.dart';
import '../../../core/presentation/controllers/reader_night_mode.dart';
import '../../../core/presentation/utils/state_status.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';
import 'package:universal_document_viewer/slides.dart';

/// Drives the PowerPoint reader (CR-OPENREADER-PPTX, UX-07) on top of
/// universal_document_viewer's [SlidesController], which owns the slides, the
/// slide on screen and search. This adds what's OpenReader's: the saved
/// position (restored on open, saved 2 s after a move and once more on
/// close), favourites/share/open-with, and the BRD §13 error wording.
class PowerPointReaderController extends BaseController with ReaderFullscreen, ReaderNightMode {
  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;
  final Future<PptxPresentation> Function(Uint8List bytes)? _parse;

  PowerPointReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
    Future<PptxPresentation> Function(Uint8List bytes)? parse,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>(),
        _parse = parse;

  static const _damaged = 'This document may be damaged or incomplete.';

  /// Created in [onInit] with the saved position; null before that.
  SlidesController? _deck;
  SlidesController get deck => _deck!;
  SlidesController? get deckOrNull => _deck;

  final hasError = false.obs;
  final isSearching = false.obs;

  List<PptxSlide> get slides => _deck?.slides ?? const [];
  int get currentSlide => _deck?.currentSlide ?? 0;
  List<SlideMatch> get matches => _deck?.matches ?? const [];
  int get currentMatch => _deck?.currentMatch ?? -1;
  String get searchQuery => _deck?.searchQuery ?? '';

  Timer? _positionSaveDebounce;
  bool _moved = false;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    status.value = StateStatus.loading;
    ReadingPosition? saved;
    final position = await _recentRepository.getPosition(document.id);
    position.fold((_) {}, (value) => saved = value);
    if (isClosed) return;
    final deck = _deck = SlidesController(initialPosition: saved, onPositionChanged: _onMoved, parse: _parse);
    // A file that can't be read fails as corrupted.
    await deck.loadFile(document.path);
    if (isClosed) return;
    switch (deck.error) {
      case DocumentLoadError.tooLarge:
        _fail('This document is too large to render safely on this device.');
      case null:
        break;
      default:
        _fail(_damaged);
    }
    status.value = !hasError.value && deck.slides.isEmpty ? StateStatus.empty : StateStatus.success;
  }

  void _fail(String message) {
    hasError.value = true;
    errorMessage.value = message;
  }

  void _onMoved(ReadingPosition _) {
    _moved = true;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  Future<void> _savePosition() => _recentRepository.markOpened(document.id, readingPosition: deck.position);

  void previousSlide() => _deck?.previousSlide();
  void nextSlide() => _deck?.nextSlide();

  void goToSlide(int number) => _deck?.goToSlide(number - 1);

  /// Whether the slide previews show above the toolbar.
  final showPreviews = false.obs;

  void togglePreviews() => showPreviews.value = !showPreviews.value;

  @override
  void onFullscreenChanged(bool fullscreen) {
    if (fullscreen) showPreviews.value = false;
  }

  void zoomIn() => _deck?.zoomIn();
  void zoomOut() => _deck?.zoomOut();

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
    _deck?.clearSearch();
  }

  void onSearchQueryChanged(String query) => _deck?.search(query);
  void goToNextMatch() => _deck?.nextMatch();
  void goToPrevMatch() => _deck?.previousMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    _interactions.readerClosedAfter(_moved ? _savePosition() : null);
    _deck?.dispose();
    super.onClose();
  }
}
