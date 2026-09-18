import 'dart:async';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';

/// Drives the Word reader (BRD §9.11, ODF-013/014, ODF-008 for Word).
///
/// `docx_file_viewer` 1.0.4's `DocxView` owns its scrolling internally and
/// exposes no `ScrollController`/initial-offset hook (confirmed by reading
/// its source, not assumed from the README) - so reading position can be
/// **saved** here (via a `NotificationListener<ScrollNotification>` in the
/// view, which observes the widget's internal scroll notifications bubbling
/// up) but not **restored**: there is no API to jump the internal scroll view
/// to a saved offset on open. Documented as a real gap (`TASK` doc), not
/// silently dropped - `_initialScrollOffset` is read back and exposed only so
/// a future library version (or a fork) has somewhere to plug it in.
///
/// Favorite/Share/Open With are delegated to the same shared
/// [DocumentInteractionController] every other reader uses, exactly like
/// `PdfReaderController`.
class WordReaderController extends BaseController {
  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;

  WordReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>();

  final searchController = DocxSearchController();
  final isSearching = false.obs;

  /// `DocxView` has no error-builder hook (unlike `pdfrx`'s
  /// `errorBannerBuilder`) - only this `onError`-style side-effect callback,
  /// so a load failure is surfaced by swapping the whole child widget for
  /// [_ReaderErrorView] rather than customizing `DocxView`'s own internal
  /// error UI. Its own "Failed to load document" text may flash briefly
  /// first, since both update from the same callback.
  final hasError = false.obs;

  void onLoadError(Object error) => hasError.value = true;

  double _initialScrollOffset = 0;
  double get initialScrollOffset => _initialScrollOffset;

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
      final offset = position['scroll_offset'];
      if (offset is num && offset > 0) _initialScrollOffset = offset.toDouble();
    });
    status.value = StateStatus.success;
  }

  /// Called from the view's `NotificationListener<ScrollNotification>` as the
  /// document scrolls, debounced the same way `PdfReaderController` debounces
  /// per-page saves.
  void onScrollOffsetChanged(double offset) {
    _lastKnownScrollOffset = offset;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(offset));
  }

  Future<void> _savePosition(double offset) => _recentRepository.markOpened(document.id, readingPosition: {'scroll_offset': offset});

  void startSearching() => isSearching.value = true;

  void stopSearching() {
    isSearching.value = false;
    searchController.clear();
  }

  void onSearchQueryChanged(String query) => searchController.search(query);

  void goToNextMatch() => searchController.nextMatch();
  void goToPrevMatch() => searchController.previousMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    if (_lastKnownScrollOffset > 0) {
      unawaited(_savePosition(_lastKnownScrollOffset));
    }
    searchController.dispose();
    super.onClose();
  }
}
