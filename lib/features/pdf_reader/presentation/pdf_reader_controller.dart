import 'dart:async';

import 'package:get/get.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';
import 'package:universal_document_viewer/pdf.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/controllers/reader_fullscreen.dart';
import '../../../core/presentation/controllers/reader_night_mode.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/show_dialog/show_dialog.dart';
import 'pdf_password_dialog.dart';

/// Drives the PDF reader (BRD 9.10, ODF-011/012, ODF-008 for PDF).
///
/// Owns reading-position persistence itself: `DocumentInteractionController
/// .openDocument()` dispatches here without calling `markOpened()`, since a
/// bare call there would reset an existing position (see that method's own
/// comment). Favorite/Share/Open With are not reimplemented here - delegated
/// to the same shared [DocumentInteractionController] every other screen
/// uses, exactly like `FileInformationController` already does.
class PdfReaderController extends BaseController with ReaderFullscreen, ReaderNightMode {
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
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl() {
    pdf = PdfController(onPositionChanged: _onPositionChanged, passwordProvider: providePassword)..addListener(_mirror);
  }

  /// universal_document_viewer's PDF state: pages, layout, zoom, search, text layer.
  late final PdfController pdf;

  int get initialPageNumber => pdf.initialPageNumber;

  // Mirrors of the kit's state, for Obx widgets and tests.
  /// The document is open (search and thumbnails need it).
  final isReady = false.obs;
  final currentPage = 1.obs;
  final pageCount = 0.obs;
  final viewMode = PdfViewMode.continuous.obs;
  final hasTextLayer = RxnBool();

  void _mirror() {
    isReady.value = pdf.status == DocumentStatus.ready;
    currentPage.value = pdf.currentPage;
    pageCount.value = pdf.pageCount;
    viewMode.value = pdf.viewMode;
    hasTextLayer.value = pdf.hasTextLayer;
  }

  final showThumbnails = false.obs;
  final isSearching = false.obs;

  /// Hides the app bar, toolbar and thumbnails (and Android's system bars) so
  /// the page fills the screen (UX-33). A tap on the page brings them back.

  /// Inverted page colours for reading in the dark (UX-33); remembered for
  /// all PDFs.
  Timer? _positionSaveDebounce;
  bool _passwordPreviouslyWrong = false;

  @override
  void onInit() {
    super.onInit();
    _loadInitialPosition().then((_) {
      if (isClosed) return;
      unawaited(_loadDefaultViewMode());
      // The document opens on the restored page; PDFium reads the file.
      unawaited(pdf.loadFile(document.path));
    });
  }

  @override
  AppSettingsRepository get readerSettings => _settingsRepository;

  @override
  void onFullscreenChanged(bool fullscreen) {
    if (fullscreen) showThumbnails.value = false;
  }

  /// Ctrl/Cmd+F: search needs the app bar, so fullscreen ends first.
  void searchFromShortcut() {
    setFullscreen(false);
    startSearching();
  }

  /// Esc: leave fullscreen, then close search, then the reader.
  void escape() {
    if (isFullscreen.value) {
      setFullscreen(false);
    } else if (isSearching.value) {
      stopSearching();
    } else {
      escapeReader();
    }
  }

  /// Toolbar zoom (UX-33), alongside pinch-to-zoom.
  void zoomIn() => pdf.zoomIn();
  void zoomOut() => pdf.zoomOut();
  void fitWidth() => pdf.fitWidth();

  /// Applies the default reading mode - the one last picked in the
  /// toolbar - only to a PDF with no remembered mode of its own (UX-19).
  Future<void> _loadDefaultViewMode() async {
    if (pdf.viewModeSettled) return;
    final continuous = await _settingsRepository.getDefaultContinuousScroll();
    pdf.applyDefaultViewMode(continuous ? PdfViewMode.continuous : PdfViewMode.horizontal);
  }

  Future<void> _loadInitialPosition() async {
    status.value = StateStatus.loading;
    final result = await _recentRepository.getPosition(document.id);
    result.fold((_) {}, pdf.restore);
    status.value = StateStatus.success;
  }

  /// A page change saves 2 s later ([toggleViewMode] saves at once).
  void _onPositionChanged(ReadingPosition _) {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), _savePosition);
  }

  /// `page_count` feeds Home's reading-progress bar (UX-13); `view_mode`
  /// makes the mode per-document (UX-19).
  Future<void> _savePosition() => _recentRepository.markOpened(document.id, readingPosition: pdf.position);

  Future<void> jumpToPage(int page) => pdf.jumpToPage(page);

  /// Switches this PDF's mode and makes it the default for PDFs opened
  /// later (the toolbar replaced Settings' default reading mode).
  void toggleViewMode() {
    pdf.toggleViewMode();
    unawaited(_settingsRepository.setDefaultContinuousScroll(pdf.viewMode == PdfViewMode.continuous));
    if (pdf.pageCount < 1) return;
    _positionSaveDebounce?.cancel();
    unawaited(_savePosition());
  }

  void toggleThumbnails() => showThumbnails.value = !showThumbnails.value;

  void startSearching() => isSearching.value = true;

  void stopSearching() {
    isSearching.value = false;
    pdf.clearSearch();
  }

  void onSearchQueryChanged(String query) => pdf.search(query);
  void goToNextMatch() => pdf.nextMatch();
  void goToPrevMatch() => pdf.previousMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);

  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);

  Future<void> share() => _interactions.shareDocument(document);

  Future<void> openWith() => _interactions.openWithExternalApp(document);

  /// [PdfPasswordProvider]: the kit asks once per attempt (after trying no
  /// password) until this returns null or the password works. A cancelled
  /// dialog leaves the reader instead of showing an error for a choice the
  /// user already made.
  Future<String?> providePassword() async {
    final entered = await showAppDialog<String>(
      child: PdfPasswordDialog(showIncorrectHint: _passwordPreviouslyWrong),
    );
    _passwordPreviouslyWrong = true;
    if (entered == null) {
      exitReader();
    }
    return entered;
  }

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    _interactions.readerClosedAfter(pdf.pageCount > 0 ? _savePosition() : null);
    pdf.dispose();
    super.onClose();
  }
}
