import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../common/reader_contract.dart';
import '../engines/pdf/viewer/pdfrx.dart';

/// How pages are laid out. A vertical single-page-snap mode isn't offered:
/// the engine's pan-based viewer has no scroll snapping, and [horizontal]
/// already covers reading one page at a time.
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

/// A search status line: "No searchable text found." for a scanned PDF
/// without a text layer, "No matches" for an ordinary zero-match search.
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

/// State for [PdfDocumentView]: the page on screen, page count, layout,
/// zoom and text search.
///
/// Position is reported through [onPositionChanged] as `{page_number,
/// page_count, view_mode}` on every page change and layout switch; saving
/// it (and debouncing) is the app's business.
class PdfDocumentController extends ChangeNotifier {
  PdfDocumentController({ReadingPosition? initialPosition, this.onPositionChanged}) {
    if (initialPosition != null) restore(initialPosition);
  }

  final ValueChanged<ReadingPosition>? onPositionChanged;

  final pdfController = PdfViewerController();

  /// Null until [onViewerReady]: the searcher's constructor reads the
  /// viewer's document immediately, which isn't attached before then.
  PdfTextSearcher? _textSearcher;
  PdfTextSearcher? get textSearcher => _textSearcher;

  bool _disposed = false;

  int _initialPage = 1;

  /// The page the viewer opens on.
  int get initialPageNumber => _initialPage;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  int _pageCount = 0;
  int get pageCount => _pageCount;

  PdfReaderViewMode _viewMode = PdfReaderViewMode.continuous;
  PdfReaderViewMode get viewMode => _viewMode;

  bool _viewModeSettled = false;

  /// Whether the layout came from a saved position or the user; an app's
  /// default layout should only apply while this is false.
  bool get viewModeSettled => _viewModeSettled;

  bool? _hasTextLayer;

  /// Null until a zero-match search has probed the text (see
  /// [probePdfTextLayer]); fixed for the document once known.
  bool? get hasTextLayer => _hasTextLayer;
  bool _probingTextLayer = false;

  /// Applies a saved position: the page to open on and, when saved, the
  /// layout. For an app that reads the position after creating this.
  void restore(ReadingPosition position) {
    if (position[PositionKeys.pageNumber] case final int page when page > 0) _initialPage = page;
    final mode = PdfReaderViewMode.values.asNameMap()[position[PositionKeys.viewMode]];
    if (mode != null && !_viewModeSettled) {
      _viewMode = mode;
      _viewModeSettled = true;
    }
    notifyListeners();
  }

  /// A default layout (e.g. from app settings) for a document with none
  /// saved; ignored once the layout is settled.
  void applyDefaultViewMode(PdfReaderViewMode mode) {
    if (_viewModeSettled) return;
    _viewMode = mode;
    notifyListeners();
  }

  ReadingPosition get position => {
        PositionKeys.pageNumber: _currentPage,
        if (_pageCount > 0) PositionKeys.pageCount: _pageCount,
        PositionKeys.viewMode: _viewMode.name,
      };

  /// [PdfViewerParams.onViewerReady].
  void onViewerReady(PdfDocument doc, PdfViewerController controller) {
    _pageCount = doc.pages.length;
    _currentPage = controller.pageNumber ?? _initialPage;
    _textSearcher ??= PdfTextSearcher(pdfController)..addListener(_onSearchProgress);
    notifyListeners();
  }

  /// [PdfViewerParams.onPageChanged].
  void onPageChanged(int? page) {
    if (page == null) return;
    _currentPage = page;
    notifyListeners();
    onPositionChanged?.call(position);
  }

  /// Stands in for [onViewerReady] where no PDF engine runs (unit tests):
  /// a real [PdfDocument] needs the native library.
  @visibleForTesting
  void debugSetPages({required int pageCount, required int currentPage}) {
    _pageCount = pageCount;
    _currentPage = currentPage;
    notifyListeners();
  }

  Future<void> jumpToPage(int page) async {
    if (_pageCount < 1) return;
    await pdfController.goToPage(pageNumber: page.clamp(1, _pageCount));
  }

  void toggleViewMode() {
    _viewModeSettled = true;
    _viewMode = _viewMode == PdfReaderViewMode.continuous ? PdfReaderViewMode.horizontal : PdfReaderViewMode.continuous;
    notifyListeners();
    if (_pageCount > 0) onPositionChanged?.call(position);
  }

  Future<void> zoomIn() async {
    if (pdfController.isReady) await pdfController.zoomUp();
  }

  Future<void> zoomOut() async {
    if (pdfController.isReady) await pdfController.zoomDown();
  }

  /// Back to the page-width zoom the viewer opens at.
  Future<void> fitWidth() async {
    if (!pdfController.isReady) return;
    final centre = pdfController.value.calcPosition(pdfController.viewSize);
    await pdfController.setZoom(centre, pdfController.coverScale);
  }

  void search(String query) {
    final searcher = _textSearcher;
    if (searcher == null) return;
    if (query.isEmpty) {
      searcher.resetTextSearch();
    } else {
      searcher.startTextSearch(query);
    }
  }

  void clearSearch() => _textSearcher?.resetTextSearch();
  Future<void> nextMatch() async => _textSearcher?.goToNextMatch();
  Future<void> previousMatch() async => _textSearcher?.goToPrevMatch();

  /// Probes the text layer once a search finishes empty. Reads each page's
  /// raw text rather than [PdfTextSearcher.loadText]: the searcher caches a
  /// page that wasn't loaded yet as empty text, which would make a text PDF
  /// still loading progressively look scanned. Raw [PdfPage.loadText]
  /// returns null for such a page instead, leaving [hasTextLayer] unknown.
  void _onSearchProgress() {
    final searcher = _textSearcher;
    if (searcher == null || _hasTextLayer != null || _probingTextLayer) return;
    if (searcher.pattern == null || searcher.isSearching || searcher.matches.isNotEmpty) return;
    _probingTextLayer = true;
    probePdfTextLayer(
      _pageCount,
      (page) async => pdfController.isReady
          ? await pdfController.useDocument<String?>((doc) async => (await doc.pages[page - 1].loadText())?.fullText)
          : null,
    ).then(
      (result) {
        if (_disposed) return;
        _hasTextLayer = result;
        notifyListeners();
      },
      // Left unknown; the next empty search probes again.
      onError: (Object _) {},
    ).whenComplete(() => _probingTextLayer = false);
  }

  @override
  void dispose() {
    _disposed = true;
    _textSearcher?.dispose();
    super.dispose();
  }
}

/// Lays pages side by side for [PdfReaderViewMode.horizontal] (the
/// engine's documented custom-layout recipe).
PdfPageLayout pdfHorizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
  final height = pages.fold(0.0, (prev, page) => max(prev, page.height)) + params.margin * 2;
  final pageLayouts = <Rect>[];
  var x = params.margin;
  for (final page in pages) {
    pageLayouts.add(Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height));
    x += page.width + params.margin;
  }
  return PdfPageLayout(pageLayouts: pageLayouts, documentSize: Size(x, height));
}
