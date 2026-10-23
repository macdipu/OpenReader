import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/utils/zip_safety_guard.dart';
import '../../../services/utilities/pptx_parser.dart';

/// Drives the PowerPoint reader (CR-OPENREADER-PPTX, UX-07): a slide-by-slide
/// reading view of a `.pptx` - titles, bullets, tables as text, pictures.
///
/// Same shape as `WordReaderController`: bytes pass [ZipSafetyGuard] before
/// anything decompresses them; parsing runs off the UI isolate; the slide
/// index is saved (debounced, and once more on close) and restored on open.
class PowerPointReaderController extends BaseController {
  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;
  final Future<PptxPresentation> Function(Uint8List bytes) _parse;

  PowerPointReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
    Future<PptxPresentation> Function(Uint8List bytes)? parse,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>(),
        _parse = parse ?? ((bytes) => Isolate.run(() => PptxParser.parse(bytes)));

  static const _damaged = 'This document may be damaged or incomplete.';

  final slides = <PptxSlide>[].obs;
  final hasError = false.obs;

  /// Zero-based slide on screen.
  final currentSlide = 0.obs;

  /// Created once the slides are known, starting on the restored slide.
  PageController? pageController;

  final isSearching = false.obs;
  final searchQuery = ''.obs;

  /// Indices of slides whose text contains [searchQuery].
  final matches = <int>[].obs;

  /// Position within [matches], or -1 before the first jump.
  final currentMatch = (-1).obs;

  Timer? _positionSaveDebounce;
  bool _moved = false;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    status.value = StateStatus.loading;
    var initialSlide = 0;
    final position = await _recentRepository.getPosition(document.id);
    position.fold((_) {}, (saved) {
      final index = saved['slide_index'];
      if (index is int && index > 0) initialSlide = index;
    });
    try {
      final bytes = await File(document.path).readAsBytes();
      switch (ZipSafetyGuard.check(bytes)) {
        case ZipSafetyResult.safe:
          final presentation = await _parse(bytes);
          if (isClosed) return;
          slides.assignAll(presentation.slides);
        case ZipSafetyResult.tooLarge:
          _fail('This document is too large to render safely on this device.');
        case ZipSafetyResult.corrupted:
          _fail(_damaged);
      }
    } catch (_) {
      _fail(_damaged);
    }
    if (isClosed) return;
    if (!hasError.value) {
      // The file may have lost slides since the position was saved.
      currentSlide.value = slides.isEmpty ? 0 : initialSlide.clamp(0, slides.length - 1);
      pageController = PageController(initialPage: currentSlide.value);
    }
    status.value = !hasError.value && slides.isEmpty ? StateStatus.empty : StateStatus.success;
  }

  void _fail(String message) {
    hasError.value = true;
    errorMessage.value = message;
  }

  /// The PageView reports every settled page here.
  void onSlideChanged(int index) {
    currentSlide.value = index;
    _moved = true;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  Future<void> _savePosition() => _recentRepository.markOpened(
        document.id,
        readingPosition: {'slide_index': currentSlide.value, 'slide_count': slides.length},
      );

  bool get canGoPrevious => currentSlide.value > 0;
  bool get canGoNext => currentSlide.value < slides.length - 1;

  void previousSlide() {
    if (canGoPrevious) goToSlide(currentSlide.value - 1);
  }

  void nextSlide() {
    if (canGoNext) goToSlide(currentSlide.value + 1);
  }

  void goToSlide(int index) {
    final controller = pageController;
    if (controller == null || !controller.hasClients) {
      onSlideChanged(index);
      return;
    }
    controller.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void startSearching() => isSearching.value = true;

  void stopSearching() {
    isSearching.value = false;
    searchQuery.value = '';
    matches.clear();
    currentMatch.value = -1;
  }

  /// Finds the slides containing [query] and jumps to the first one at or
  /// after the slide on screen.
  void onSearchQueryChanged(String query) {
    searchQuery.value = query;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      matches.clear();
      currentMatch.value = -1;
      return;
    }
    matches.assignAll([
      for (var i = 0; i < slides.length; i++)
        if (slides[i].text.toLowerCase().contains(needle)) i,
    ]);
    if (matches.isEmpty) {
      currentMatch.value = -1;
      return;
    }
    final ahead = matches.indexWhere((i) => i >= currentSlide.value);
    _goToMatch(ahead == -1 ? 0 : ahead);
  }

  void goToNextMatch() {
    if (matches.isNotEmpty) _goToMatch((currentMatch.value + 1) % matches.length);
  }

  void goToPrevMatch() {
    if (matches.isNotEmpty) _goToMatch((currentMatch.value - 1 + matches.length) % matches.length);
  }

  void _goToMatch(int index) {
    currentMatch.value = index;
    goToSlide(matches[index]);
  }

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    _interactions.readerClosedAfter(_moved ? _savePosition() : null);
    pageController?.dispose();
    super.onClose();
  }
}
