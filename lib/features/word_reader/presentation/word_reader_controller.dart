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
import 'package:open_reader_kit/docx.dart';
import 'package:open_reader_kit/open_reader_kit.dart';

/// Drives the Word reader (BRD §9.11, ODF-013/014, ODF-008 for Word) on
/// top of open_reader_kit's [WordDocumentController], which checks the
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
    word = WordDocumentController(onPositionChanged: (p) => onScrollOffsetChanged(p[PositionKeys.scrollOffset]! as double))
      ..addListener(_onWordChanged);
  }

  late final WordDocumentController word;

  WordSearchController get searchController => word.searchController;
  ScrollController get scrollController => word.scrollController;
  double get initialScrollOffset => word.initialScrollOffset;

  final isSearching = false.obs;

  /// A load failure swaps the whole body for the error view.
  final hasError = false.obs;

  void _onWordChanged() {
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

  double _lastKnownScrollOffset = 0;
  Timer? _positionSaveDebounce;

  @override
  void onInit() {
    super.onInit();
    _loadInitialPosition();
  }

  Future<void> _loadInitialPosition() async {
    status.value = StateStatus.loading;
    final result = await _recentRepository.getPosition(document.id);
    result.fold((_) {}, (position) {
      final offset = position[PositionKeys.scrollOffset];
      if (offset is num && offset > 0) word.initialScrollOffset = offset.toDouble();
    });
    try {
      await word.load(await File(document.path).readAsBytes());
    } catch (_) {
      word.rejectAsCorrupted();
    }
    status.value = StateStatus.success;
  }

  /// Called as the document scrolls (through the kit), debounced the same
  /// way `PdfReaderController` debounces per-page saves.
  void onScrollOffsetChanged(double offset) {
    _lastKnownScrollOffset = offset;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(offset));
  }

  Future<void> _savePosition(double offset) =>
      _recentRepository.markOpened(document.id, readingPosition: {PositionKeys.scrollOffset: offset});

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
    _positionSaveDebounce?.cancel();
    _interactions.readerClosedAfter(_lastKnownScrollOffset > 0 ? _savePosition(_lastKnownScrollOffset) : null);
    word.dispose();
    super.onClose();
  }
}
