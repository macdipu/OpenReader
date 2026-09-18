import 'dart:async';

import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
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

  PdfReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>();

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

  int _initialPage = 1;
  int get initialPageNumber => _initialPage;

  Timer? _positionSaveDebounce;
  bool _passwordPreviouslyWrong = false;

  @override
  void onInit() {
    super.onInit();
    _loadInitialPosition();
  }

  Future<void> _loadInitialPosition() async {
    status.value = StateStatus.loading;
    final result = await _recentRepository.getPosition(document.id);
    result.fold((_) {}, (position) {
      final page = position['page_number'];
      if (page is int && page > 0) _initialPage = page;
    });
    status.value = StateStatus.success;
  }

  /// [PdfViewerParams.onViewerReady].
  void onViewerReady(PdfDocument doc, PdfViewerController controller) {
    pageCount.value = doc.pages.length;
    currentPage.value = controller.pageNumber ?? _initialPage;
    textSearcher.value ??= PdfTextSearcher(pdfController);
  }

  /// [PdfViewerParams.onPageChanged].
  void onPageChanged(int? page) {
    if (page == null) return;
    currentPage.value = page;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(page));
  }

  Future<void> _savePosition(int page) => _recentRepository.markOpened(document.id, readingPosition: {'page_number': page});

  Future<void> jumpToPage(int page) async {
    if (pageCount.value < 1) return;
    await pdfController.goToPage(pageNumber: page.clamp(1, pageCount.value));
  }

  void toggleViewMode() {
    viewMode.value = viewMode.value == PdfReaderViewMode.continuous ? PdfReaderViewMode.horizontal : PdfReaderViewMode.continuous;
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
    if (pageCount.value > 0) {
      unawaited(_savePosition(currentPage.value));
    }
    textSearcher.value?.dispose();
    super.onClose();
  }
}
