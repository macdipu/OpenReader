import 'dart:async';

import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/show_dialog/show_dialog.dart';
import 'pdf_password_dialog.dart';

/// BRD 9.10 lists "Single-page mode," "Continuous vertical mode," and
/// "Horizontal page mode" as three distinct view modes. This reader ships
/// two: [continuous] (pdfrx's default vertical scroll) and [horizontal]
/// (paged, via pdfrx's documented custom-layout recipe). A true vertical
/// single-page-snap mode is deliberately not a third option here - it needs
/// scroll-snap behavior pdfrx's pan-based viewer doesn't provide out of the
/// box, and [horizontal] already covers "read one page at a time via
/// discrete navigation." Flagged here rather than silently claimed as done.
enum PdfReaderViewMode { continuous, horizontal }

/// Whether any of the document's [pageCount] pages carries text. Stops at
/// the first non-blank page. `false` only when every page loaded and was
/// blank (a scanned PDF); `null` when a page wasn't loaded yet
/// ([loadPageText] returns null for it under progressive loading), so the
/// answer is unknown rather than "no text".
Future<bool?> probePdfTextLayer(int pageCount, Future<String?> Function(int pageNumber) loadPageText) async {
  var allLoaded = true;
  for (var page = 1; page <= pageCount; page++) {
    final text = await loadPageText(page);
    if (text == null) {
      allLoaded = false;
    } else if (text.trim().isNotEmpty) {
      return true;
    }
  }
  return allLoaded ? false : null;
}

/// The PDF search status line. BRD line 1087's "No searchable text found."
/// is for scanned PDFs without a text layer; an ordinary zero-match search
/// says "No matches", like the other readers (CR-OPENREADER-UX UX-26).
String pdfSearchStatusLabel({
  required bool hasPattern,
  required bool isSearching,
  required int matchCount,
  required int? currentIndex,
  required bool? hasTextLayer,
}) {
  if (!hasPattern) return '';
  if (isSearching) return 'Searching…';
  if (matchCount == 0) return hasTextLayer == false ? 'No searchable text found.' : 'No matches';
  return '${(currentIndex ?? 0) + 1} of $matchCount result(s)';
}

/// Drives the PDF reader (BRD 9.10, ODF-011/012, ODF-008 for PDF).
///
/// Owns reading-position persistence itself: `DocumentInteractionController
/// .openDocument()` dispatches here without calling `markOpened()`, since a
/// bare call there would reset an existing position (see that method's own
/// comment). Favorite/Share/Open With are not reimplemented here - delegated
/// to the same shared [DocumentInteractionController] every other screen
/// uses, exactly like `FileInformationController` already does.
class PdfReaderController extends BaseController {
  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;
  final AppSettingsRepository _settingsRepository;

  PdfReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
    AppSettingsRepository? settingsRepository,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>(),
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl();

  final pdfController = PdfViewerController();

  /// `null` until [onViewerReady] fires. [PdfTextSearcher]'s constructor
  /// dereferences `pdfController.isReady`'s document immediately, so
  /// building it eagerly (e.g. a `late final` field initializer, run on
  /// first access from the very first widget build) throws a null-check
  /// error - the viewer has no document attached yet at that point.
  final textSearcher = Rxn<PdfTextSearcher>();

  final currentPage = 1.obs;
  final pageCount = 0.obs;
  final viewMode = PdfReaderViewMode.continuous.obs;
  final showThumbnails = false.obs;
  final isSearching = false.obs;

  /// `null` until a zero-match search has probed the text (see
  /// [probePdfTextLayer]); fixed for the document once known.
  final hasTextLayer = RxnBool();
  bool _probingTextLayer = false;

  int _initialPage = 1;
  int get initialPageNumber => _initialPage;

  Timer? _positionSaveDebounce;
  bool _passwordPreviouslyWrong = false;

  /// Set once the view mode is settled - by the user's toggle or this
  /// document's remembered mode - so neither async read below can override
  /// it afterwards (a quick toggle used to be reset by the late default).
  bool _viewModeSettled = false;

  @override
  void onInit() {
    super.onInit();
    _loadInitialPosition().then((_) => _loadDefaultViewMode());
  }

  /// Applies the Settings > Reading Engine Preferences default (BRD 9.18)
  /// only to a PDF with no remembered mode of its own (UX-19).
  Future<void> _loadDefaultViewMode() async {
    if (_viewModeSettled) return;
    final continuous = await _settingsRepository.getDefaultContinuousScroll();
    if (_viewModeSettled) return;
    viewMode.value = continuous ? PdfReaderViewMode.continuous : PdfReaderViewMode.horizontal;
  }

  Future<void> _loadInitialPosition() async {
    status.value = StateStatus.loading;
    final result = await _recentRepository.getPosition(document.id);
    result.fold((_) {}, (position) {
      final page = position['page_number'];
      if (page is int && page > 0) _initialPage = page;
      final mode = PdfReaderViewMode.values.asNameMap()[position['view_mode']];
      if (mode != null && !_viewModeSettled) {
        viewMode.value = mode;
        _viewModeSettled = true;
      }
    });
    status.value = StateStatus.success;
  }

  /// [PdfViewerParams.onViewerReady].
  void onViewerReady(PdfDocument doc, PdfViewerController controller) {
    pageCount.value = doc.pages.length;
    currentPage.value = controller.pageNumber ?? _initialPage;
    textSearcher.value ??= PdfTextSearcher(pdfController)..addListener(_onSearchProgress);
  }

  /// Probes the text layer once a search finishes empty. Reads each page's
  /// raw text rather than [PdfTextSearcher.loadText]: the searcher caches a
  /// page that wasn't loaded yet as empty text, which would make a text PDF
  /// still loading progressively look scanned. Raw [PdfPage.loadText]
  /// returns null for such a page instead, leaving [hasTextLayer] unknown.
  void _onSearchProgress() {
    final searcher = textSearcher.value;
    if (searcher == null || hasTextLayer.value != null || _probingTextLayer) return;
    if (searcher.pattern == null || searcher.isSearching || searcher.matches.isNotEmpty) return;
    _probingTextLayer = true;
    probePdfTextLayer(
      pageCount.value,
      (page) async => pdfController.isReady
          ? await pdfController.useDocument<String?>((doc) async => (await doc.pages[page - 1].loadText())?.fullText)
          : null,
    ).then((result) {
      if (!isClosed) hasTextLayer.value = result;
    }).whenComplete(() => _probingTextLayer = false);
  }

  /// [PdfViewerParams.onPageChanged].
  void onPageChanged(int? page) {
    if (page == null) return;
    currentPage.value = page;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(page));
  }

  /// `page_count` feeds Home's reading-progress bar (UX-13); `view_mode`
  /// makes the mode per-document (UX-19).
  Future<void> _savePosition(int page) => _recentRepository.markOpened(document.id, readingPosition: {
        'page_number': page,
        if (pageCount.value > 0) 'page_count': pageCount.value,
        'view_mode': viewMode.value.name,
      });

  Future<void> jumpToPage(int page) async {
    if (pageCount.value < 1) return;
    await pdfController.goToPage(pageNumber: page.clamp(1, pageCount.value));
  }

  void toggleViewMode() {
    _viewModeSettled = true;
    viewMode.value = viewMode.value == PdfReaderViewMode.continuous ? PdfReaderViewMode.horizontal : PdfReaderViewMode.continuous;
    if (pageCount.value > 0) unawaited(_savePosition(currentPage.value));
  }

  void toggleThumbnails() => showThumbnails.value = !showThumbnails.value;

  void startSearching() => isSearching.value = true;

  void stopSearching() {
    isSearching.value = false;
    textSearcher.value?.resetTextSearch();
  }

  void onSearchQueryChanged(String query) {
    final searcher = textSearcher.value;
    if (searcher == null) return;
    if (query.isEmpty) {
      searcher.resetTextSearch();
    } else {
      searcher.startTextSearch(query);
    }
  }

  Future<void> goToNextMatch() async => textSearcher.value?.goToNextMatch();

  Future<void> goToPrevMatch() async => textSearcher.value?.goToPrevMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);

  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);

  Future<void> share() => _interactions.shareDocument(document);

  Future<void> openWith() => _interactions.openWithExternalApp(document);

  /// [PdfPasswordProvider]: pdfrx calls this once per attempt (first with an
  /// empty password automatically, then once per retry) until it returns
  /// null or the password succeeds - see `PdfDocument`'s own retry loop. A
  /// cancelled dialog leaves the reader instead of surfacing a raw
  /// [PdfPasswordException] banner for a choice the user already made.
  Future<String?> providePassword() async {
    final entered = await showAppDialog<String>(
      child: PdfPasswordDialog(showIncorrectHint: _passwordPreviouslyWrong),
    );
    _passwordPreviouslyWrong = true;
    if (entered == null) {
      Get.back();
    }
    return entered;
  }

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    _interactions.readerClosedAfter(pageCount.value > 0 ? _savePosition(currentPage.value) : null);
    textSearcher.value?.dispose();
    super.onClose();
  }
}
