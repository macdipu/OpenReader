import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import 'package:open_reader_kit/open_reader_kit.dart';
import 'package:open_reader_kit/text.dart';

/// Drives the Text reader (BRD §9.14, ODF-019, ODF-008 for TXT) on top of
/// open_reader_kit's [TextDocumentController], which owns the lines,
/// search and scrolling. This adds what's OpenReader's: the saved position
/// (restored on open, saved 2 s after scrolling and once more on close),
/// font size and wrap remembered across files (UX-20), favourites/share/
/// open-with, and the BRD §13 error wording.
class TextReaderController extends BaseController {
  /// See [TextDocumentController.maxBytes].
  static const int maxBytes = TextDocumentController.maxBytes;

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
    textDocument = TextDocumentController(onPositionChanged: (p) => onScrolled(p[PositionKeys.scrollOffset]! as double))
      ..addListener(_mirrorSearch);
  }

  late final TextDocumentController textDocument;

  List<String> get lines => textDocument.lines;
  ScrollController get scrollController => textDocument.scrollController;

  double Function(int lineIndex)? get lineOffsetResolver => textDocument.lineOffsetResolver;
  set lineOffsetResolver(double Function(int lineIndex)? resolver) => textDocument.lineOffsetResolver = resolver;

  double get initialScrollOffset => textDocument.initialScrollOffset;

  final fontSize = 14.0.obs;
  final lineWrap = true.obs;

  final isSearching = false.obs;

  /// Mirrors of the kit's search state, for the app bar's Obx widgets.
  final searchQuery = ''.obs;
  final matches = <int>[].obs; // matching line indices
  final currentMatchIndex = (-1).obs;

  void _mirrorSearch() {
    searchQuery.value = textDocument.searchQuery;
    if (!listEquals(matches, textDocument.matches)) matches.assignAll(textDocument.matches);
    currentMatchIndex.value = textDocument.currentMatch;
  }

  /// Last offset reported by [onScrolled]. A close saves this: by `onClose`
  /// the list has detached from [scrollController], so reading it then lost
  /// any scrolling since the last debounced save (P2r1-review #2).
  double _lastScrollOffset = 0;

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
      if (wrap != null && !_lineWrapChosen) lineWrap.value = wrap;
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
          textDocument.initialScrollOffset = _lastScrollOffset = offset.toDouble();
        }
      });

      // Refuse an oversized file before reading it into memory.
      final file = File(document.path);
      if (await file.length() > maxBytes) {
        _fail('This document is too large to render safely on this device.');
        return;
      }
      textDocument.load(await file.readAsBytes());
      if (textDocument.error != null) {
        _fail(textDocument.error == DocumentLoadError.tooLarge
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
  void onScrolled(double offset) {
    _lastScrollOffset = offset;
    _scrolledThisSession = true;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(offset));
  }

  Future<void> _savePosition(double offset) =>
      _recentRepository.markOpened(document.id, readingPosition: {PositionKeys.scrollOffset: offset});

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
    unawaited(_settingsRepository.setTextReaderLineWrap(lineWrap.value));
  }

  void startSearching() => isSearching.value = true;

  void stopSearching() {
    isSearching.value = false;
    textDocument.clearSearch();
  }

  void search(String query) => textDocument.search(query);
  void goToNextMatch() => textDocument.nextMatch();
  void goToPrevMatch() => textDocument.previousMatch();

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    final save = _scrolledThisSession || _lastScrollOffset > 0;
    _interactions.readerClosedAfter(save ? _savePosition(_lastScrollOffset) : null);
    textDocument.dispose();
    super.onClose();
  }
}
