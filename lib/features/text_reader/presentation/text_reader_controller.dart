import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

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
import 'package:universal_document_viewer/universal_document_viewer.dart';

/// Drives the Text reader (BRD §9.14, ODF-019, ODF-008 for TXT) on top of
/// universal_document_viewer's [PlainTextController], which owns the lines,
/// search and scrolling. This adds what's OpenReader's: the saved position
/// (restored on open, saved 2 s after scrolling and once more on close),
/// font size and wrap remembered across files (UX-20), favourites/share/
/// open-with, and the BRD §13 error wording.
class TextReaderController extends BaseController with ReaderFullscreen, ReaderNightMode {
  /// See [PlainTextController.maxBytes].
  static const int maxBytes = PlainTextController.maxBytes;

  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;
  final AppSettingsRepository _settingsRepository;

  TextReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
    AppSettingsRepository? settingsRepository,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>(),
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl() {
    void report(ReadingPosition p) => onScrolled(p[PositionKeys.scrollOffset]! as double, line: p[PositionKeys.line] as int?);
    // .md/.markdown get the kit's Preview/Code/Split reader; other text stays plain.
    lineSource = MarkdownController.isMarkdownExtension(document.extension)
        ? MarkdownController(onPositionChanged: report, baseDirectory: p.dirname(document.path))
        : PlainTextController(onPositionChanged: report);
    lineSource.addListener(_mirrorSearch);
    markdown?.viewMode.addListener(_mirrorViewMode);
  }

  /// The lines, search and zoom of either reader: plain text or Markdown.
  late final TextLinesController lineSource;

  /// The plain-text document, or null for a Markdown file.
  PlainTextController? get plainText => lineSource is PlainTextController ? lineSource as PlainTextController : null;

  /// The plain-text document; only for the plain reader.
  PlainTextController get textDocument => lineSource as PlainTextController;

  /// The Markdown document, or null for any other text file.
  MarkdownController? get markdown => lineSource is MarkdownController ? lineSource as MarkdownController : null;

  bool get isMarkdown => markdown != null;

  /// Mirror of the kit's Markdown view mode, for the app bar's Obx widgets.
  final viewMode = MarkdownViewMode.preview.obs;

  void _mirrorViewMode() => viewMode.value = markdown!.viewMode.value;

  void setViewMode(MarkdownViewMode mode) => markdown?.setViewMode(mode);

  /// Counts for the Details dialog; null for non-Markdown files.
  MarkdownStats? get markdownStats => markdown?.stats;

  /// Puts the whole source on the clipboard.
  Future<void> copySource() => Clipboard.setData(ClipboardData(text: markdown?.source ?? lines.join('\n')));

  List<String> get lines => lineSource.lines;


  double get initialScrollOffset => lineSource.initialScrollOffset;

  /// A comfortable reading size until the reader picks one (UX-20).
  static const double defaultFontSize = 16;

  final fontSize = defaultFontSize.obs;

  /// The (1-based) line at the top of the view, for the toolbar.
  final topLine = 1.obs;
  final lineWrap = true.obs;

  final isSearching = false.obs;

  /// Mirrors of the kit's search state, for the app bar's Obx widgets.
  final searchQuery = ''.obs;
  final matches = <TextMatch>[].obs;
  final currentMatchIndex = (-1).obs;

  void _mirrorSearch() {
    searchQuery.value = lineSource.searchQuery;
    if (!listEquals(matches, lineSource.matches)) matches.assignAll(lineSource.matches);
    currentMatchIndex.value = lineSource.currentMatch;
  }

  /// Last offset reported by [onScrolled]. A close saves this: by `onClose`
  /// the list has detached from [scrollController], so reading it then lost
  /// any scrolling since the last debounced save.
  double _lastScrollOffset = 0;

  /// The top line reported with [_lastScrollOffset], saved with it for the
  /// resumed-page thumbnail.
  int? _lastLine;

  /// Whether the user scrolled this session, so a close saves even a
  /// return to the very top (offset 0) over an older saved position.
  bool _scrolledThisSession = false;

  Timer? _positionSaveDebounce;

  /// Set once the user changes font size or wrap, so the saved preference
  /// read in [_loadPreferences] can't override that change.
  bool _fontSizeChosen = false;
  bool _lineWrapChosen = false;

  @override
  void onInit() {
    super.onInit();
    _loadPreferences();
    _load();
  }

  /// Font size and wrap are remembered across files and launches (UX-20).
  Future<void> _loadPreferences() async {
    try {
      final size = await _settingsRepository.getTextReaderFontSize();
      if (size != null && !_fontSizeChosen) fontSize.value = size.clamp(minFontSize, maxFontSize);
      final wrap = await _settingsRepository.getTextReaderLineWrap();
      if (wrap != null && !_lineWrapChosen) {
        lineWrap.value = wrap;
        plainText?.wrap = wrap;
      }
    } catch (_) {
      // Preferences are a convenience; the reader works with the defaults.
    }
  }

  Future<void> _load() async {
    status.value = StateStatus.loading;
    try {
      final positionResult = await _recentRepository.getPosition(document.id);
      positionResult.fold((_) {}, (position) {
        final offset = position[PositionKeys.scrollOffset];
        if (offset is num && offset > 0) {
          lineSource.initialScrollOffset = _lastScrollOffset = offset.toDouble();
          if (position[PositionKeys.line] case final int line) _lastLine = line;
        }
      });

      // Refuses an oversized file before reading it into memory.
      await lineSource.loadFile(document.path);
      if (isClosed) return;
      if (lineSource.error != null) {
        _fail(lineSource.error == DocumentLoadError.tooLarge
            ? 'This document is too large to render safely on this device.'
            : 'This document may be damaged or incomplete.');
        return;
      }
      status.value = StateStatus.success;
    } catch (e) {
      _fail('This document may be damaged or incomplete.');
    }
  }

  void _fail(String message) {
    status.value = StateStatus.error;
    errorMessage.value = message;
  }

  /// Takes the offset explicitly (rather than reading `scrollController`
  /// itself) so the debounce logic is testable without a real attached
  /// `Scrollable`, the same shape the Word reader's scroll reporting
  /// and the Excel/CSV readers' `onScrolled` use.
  void onScrolled(double offset, {int? line}) {
    if (line != null) topLine.value = line + 1;
    _lastScrollOffset = offset;
    _lastLine = line;
    _scrolledThisSession = true;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(offset, line));
  }

  Future<void> _savePosition(double offset, int? line) => _recentRepository.markOpened(
        document.id,
        readingPosition: {PositionKeys.scrollOffset: offset, if (line != null) PositionKeys.line: line},
      );

  static const double minFontSize = 10;
  static const double maxFontSize = 32;

  void increaseFontSize() => _setFontSize(fontSize.value + 2);
  void decreaseFontSize() => _setFontSize(fontSize.value - 2);

  void _setFontSize(double value) {
    _fontSizeChosen = true;
    fontSize.value = value.clamp(minFontSize, maxFontSize);
    unawaited(_settingsRepository.setTextReaderFontSize(fontSize.value));
  }

  void toggleLineWrap() {
    _lineWrapChosen = true;
    lineWrap.value = !lineWrap.value;
    plainText?.wrap = lineWrap.value;
    unawaited(_settingsRepository.setTextReaderLineWrap(lineWrap.value));
  }

  @override
  AppSettingsRepository get readerSettings => _settingsRepository;

  bool get canIncreaseFontSize => fontSize.value < maxFontSize;
  bool get canDecreaseFontSize => fontSize.value > minFontSize;

  /// Scrolls line [number] (1-based) to the top.
  void goToLine(int number) => lineSource.goTo(number);

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
    lineSource.clearSearch();
  }

  void search(String query) => lineSource.search(query);
  void goToNextMatch() => lineSource.nextMatch();
  void goToPrevMatch() => lineSource.previousMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    final save = _scrolledThisSession || _lastScrollOffset > 0;
    _interactions.readerClosedAfter(save ? _savePosition(_lastScrollOffset, _lastLine) : null);
    markdown?.viewMode.removeListener(_mirrorViewMode);
    lineSource.dispose();
    super.onClose();
  }
}
