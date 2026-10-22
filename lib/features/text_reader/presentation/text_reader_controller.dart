import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import '../../../core/presentation/utils/text_decoding.dart';

/// Drives the Text reader (BRD §9.14, ODF-019, ODF-008 for TXT).
///
/// Unlike the Word reader (`FEATURE-OPENREADER-P3`, which wraps a third-party
/// widget with no scroll-control API), this reader owns a real
/// [ScrollController] over first-party content, so reading position works
/// both ways: saved **and** restored - no equivalent gap.
///
/// No library is used or needed (`FEATURE-OPENREADER-P4/ARCHITECTURE.md`
/// Alternatives Considered) - plain text has no format to parse.
class TextReaderController extends BaseController {
  /// Above this size, the file is refused rather than read into memory in
  /// one pass - BRD §13's existing "too large to render safely" message,
  /// same posture as every prior reader's own large-file risk. Not derived
  /// from a BRD-specified number (none exists); a first-pass, adjustable
  /// constant.
  static const int maxBytes = 20 * 1024 * 1024;

  /// Fallback line height for jump-to-match when no [lineOffsetResolver] is
  /// attached (the view sets one that measures real lines - UX-21).
  static const double _approxLineHeight = 20;

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
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl();

  List<String> _lines = const [];
  List<String> get lines => _lines;

  final fontSize = 14.0.obs;
  final lineWrap = true.obs;

  final isSearching = false.obs;
  final searchQuery = ''.obs;
  final matches = <int>[].obs; // matching line indices
  final currentMatchIndex = (-1).obs;

  final scrollController = ScrollController();

  /// Scroll offset of a line's top, measured by the view against the real
  /// font, width and wrap (UX-21). Null until the view lays out.
  double Function(int lineIndex)? lineOffsetResolver;

  double _initialScrollOffset = 0;
  double get initialScrollOffset => _initialScrollOffset;

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
        final offset = position['scroll_offset'];
        if (offset is num && offset > 0) _initialScrollOffset = _lastScrollOffset = offset.toDouble();
      });

      final file = File(document.path);
      final length = await file.length();
      if (length > maxBytes) {
        status.value = StateStatus.error;
        errorMessage.value = 'This document is too large to render safely on this device.';
        return;
      }

      final bytes = await file.readAsBytes();
      if (_looksBinary(bytes)) {
        status.value = StateStatus.error;
        errorMessage.value = 'This document may be damaged or incomplete.';
        return;
      }

      _lines = decodeTextBytes(bytes).split('\n');
      status.value = StateStatus.success;
    } catch (e) {
      status.value = StateStatus.error;
      errorMessage.value = 'This document may be damaged or incomplete.';
    }
  }

  /// A cheap heuristic, not a real content-type sniffer: a NUL byte, or a
  /// high proportion of non-whitespace control bytes in a leading sample,
  /// is treated as "not text" (BRD §9.14 Corner Case: "Binary file renamed
  /// as `.txt`"). False positives/negatives are possible on edge-case files;
  /// accepted as a documented simplification.
  bool _looksBinary(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final sampleSize = bytes.length < 8000 ? bytes.length : 8000;
    var controlCount = 0;
    for (var i = 0; i < sampleSize; i++) {
      final b = bytes[i];
      if (b == 0) return true;
      final isCommonWhitespace = b == 0x09 || b == 0x0A || b == 0x0D;
      if (!isCommonWhitespace && b < 0x20) controlCount++;
    }
    return controlCount / sampleSize > 0.05;
  }

  /// Takes the offset explicitly (rather than reading `scrollController`
  /// itself) so the debounce logic is testable without a real attached
  /// `Scrollable`, the same shape `WordReaderController.onScrollOffsetChanged`
  /// and the Excel/CSV readers' `onScrolled` use.
  void onScrolled(double offset) {
    _lastScrollOffset = offset;
    _scrolledThisSession = true;
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(offset));
  }

  Future<void> _savePosition(double offset) => _recentRepository.markOpened(document.id, readingPosition: {'scroll_offset': offset});

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
    searchQuery.value = '';
    matches.clear();
    currentMatchIndex.value = -1;
  }

  void search(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      matches.clear();
      currentMatchIndex.value = -1;
      return;
    }
    final lower = query.toLowerCase();
    final found = <int>[];
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].toLowerCase().contains(lower)) found.add(i);
    }
    matches.assignAll(found);
    currentMatchIndex.value = found.isEmpty ? -1 : 0;
    if (found.isNotEmpty) _jumpToLine(found.first);
  }

  void goToNextMatch() {
    if (matches.isEmpty) return;
    currentMatchIndex.value = (currentMatchIndex.value + 1) % matches.length;
    _jumpToLine(matches[currentMatchIndex.value]);
  }

  void goToPrevMatch() {
    if (matches.isEmpty) return;
    currentMatchIndex.value = (currentMatchIndex.value - 1 + matches.length) % matches.length;
    _jumpToLine(matches[currentMatchIndex.value]);
  }

  void _jumpToLine(int lineIndex) {
    if (!scrollController.hasClients) return;
    final offset = lineOffsetResolver?.call(lineIndex) ?? lineIndex * _approxLineHeight;
    final target = offset.clamp(0.0, scrollController.position.maxScrollExtent);
    scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    final save = _scrolledThisSession || _lastScrollOffset > 0;
    _interactions.readerClosedAfter(save ? _savePosition(_lastScrollOffset) : null);
    scrollController.dispose();
    super.onClose();
  }
}
