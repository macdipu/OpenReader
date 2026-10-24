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
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/show_dialog/show_dialog.dart';
import 'pdf_password_dialog.dart';
import 'package:flutter/services.dart';
import '../../../core/presentation/utils/platform_info.dart';

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
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl() {
    pdf = PdfDocumentController(onPositionChanged: _onPositionChanged)..addListener(_mirror);
  }

  /// universal_document_viewer's PDF state: pages, layout, zoom, search, text layer.
  late final PdfDocumentController pdf;

  int get initialPageNumber => pdf.initialPageNumber;

  /// The kit's search: query, matches, current match (a Listenable).
  PdfSearchController get searchController => pdf.searchController;

  // Mirrors of the kit's state, for Obx widgets and tests.
  /// The document is open (search and thumbnails need it).
  final isReady = false.obs;
  final currentPage = 1.obs;
  final pageCount = 0.obs;
  final viewMode = PdfReaderViewMode.continuous.obs;
  final hasTextLayer = RxnBool();

  void _mirror() {
    isReady.value = pdf.isReady;
    currentPage.value = pdf.currentPage;
    pageCount.value = pdf.pageCount;
    viewMode.value = pdf.viewMode;
    hasTextLayer.value = pdf.hasTextLayer;
  }

  final showThumbnails = false.obs;
  final isSearching = false.obs;

  /// Hides the app bar, toolbar and thumbnails (and Android's system bars) so
  /// the page fills the screen (UX-33). A tap on the page brings them back.
  final isFullscreen = false.obs;

  /// Inverted page colours for reading in the dark (UX-33); remembered for
  /// all PDFs.
  final nightMode = false.obs;

  Timer? _positionSaveDebounce;
  bool _passwordPreviouslyWrong = false;

  @override
  void onInit() {
    super.onInit();
    _loadInitialPosition().then((_) => _loadDefaultViewMode());
    _loadNightMode();
  }

  Future<void> _loadNightMode() async {
    try {
      nightMode.value = await _settingsRepository.getPdfNightMode() ?? false;
    } catch (_) {
      // A preference, not a requirement - the reader works without it.
    }
  }

  void toggleNightMode() {
    nightMode.value = !nightMode.value;
    unawaited(_settingsRepository.setPdfNightMode(nightMode.value));
  }

  void toggleFullscreen() => _setFullscreen(!isFullscreen.value);

  void _setFullscreen(bool value) {
    isFullscreen.value = value;
    if (value) showThumbnails.value = false;
    // System bars exist only on Android; desktop embedders don't implement
    // this call and would throw.
    if (!PlatformInfo.isAndroid) return;
    unawaited(SystemChrome.setEnabledSystemUIMode(value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge));
  }

  /// Ctrl/Cmd+F: search needs the app bar, so fullscreen ends first.
  void searchFromShortcut() {
    if (isFullscreen.value) _setFullscreen(false);
    startSearching();
  }

  /// Esc: leave fullscreen, then close search, then the reader.
  void escape() {
    if (isFullscreen.value) {
      _setFullscreen(false);
    } else if (isSearching.value) {
      stopSearching();
    } else {
      Get.back();
    }
  }

  /// Toolbar zoom (UX-33), alongside pinch-to-zoom.
  Future<void> zoomIn() => pdf.zoomIn();
  Future<void> zoomOut() => pdf.zoomOut();
  Future<void> fitWidth() => pdf.fitWidth();

  /// Applies the Settings > Reading Engine Preferences default (BRD 9.18)
  /// only to a PDF with no remembered mode of its own (UX-19).
  Future<void> _loadDefaultViewMode() async {
    if (pdf.viewModeSettled) return;
    final continuous = await _settingsRepository.getDefaultContinuousScroll();
    pdf.applyDefaultViewMode(continuous ? PdfReaderViewMode.continuous : PdfReaderViewMode.horizontal);
  }

  Future<void> _loadInitialPosition() async {
    status.value = StateStatus.loading;
    final result = await _recentRepository.getPosition(document.id);
    result.fold((_) {}, pdf.restore);
    status.value = StateStatus.success;
  }

  /// The page being read (1-based), as the kit's view reports it.
  void onPageChanged(int? page) {
    if (page != null) pdf.onPageChanged(page);
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

  void toggleViewMode() {
    pdf.toggleViewMode();
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
  Future<void> goToNextMatch() => pdf.nextMatch();
  Future<void> goToPrevMatch() => pdf.previousMatch();

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
      Get.back();
    }
    return entered;
  }

  @override
  void onClose() {
    if (isFullscreen.value) _setFullscreen(false);
    _positionSaveDebounce?.cancel();
    _interactions.readerClosedAfter(pdf.pageCount > 0 ? _savePosition() : null);
    pdf.dispose();
    super.onClose();
  }
}
