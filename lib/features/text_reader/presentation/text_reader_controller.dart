import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
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

  /// Rough single-line height estimate used only to approximate a jump-to-
  /// match scroll offset (`goToNextMatch`/`goToPrevMatch`) - wrapped long
  /// lines make an exact offset impractical without per-line layout
  /// measurement. A documented simplification, not pixel-perfect.
  static const double _approxLineHeight = 20;

  final DocumentModel document;
  final RecentRepository _recentRepository;
  final DocumentInteractionController _interactions;

  TextReaderController({
    required this.document,
    RecentRepository? recentRepository,
    DocumentInteractionController? interactions,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _interactions = interactions ?? Get.find<DocumentInteractionController>();

  List<String> _lines = const [];
  List<String> get lines => _lines;

  final fontSize = 14.0.obs;
  final lineWrap = true.obs;

  final isSearching = false.obs;
  final searchQuery = ''.obs;
  final matches = <int>[].obs; // matching line indices
  final currentMatchIndex = (-1).obs;

  final scrollController = ScrollController();

  double _initialScrollOffset = 0;
  double get initialScrollOffset => _initialScrollOffset;

  Timer? _positionSaveDebounce;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    status.value = StateStatus.loading;
    try {
      final positionResult = await _recentRepository.getPosition(document.id);
      positionResult.fold((_) {}, (position) {
        final offset = position['scroll_offset'];
        if (offset is num && offset > 0) _initialScrollOffset = offset.toDouble();
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
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(seconds: 2), () => _savePosition(offset));
  }

  Future<void> _savePosition(double offset) => _recentRepository.markOpened(document.id, readingPosition: {'scroll_offset': offset});

  void increaseFontSize() => fontSize.value = (fontSize.value + 2).clamp(10, 32);
  void decreaseFontSize() => fontSize.value = (fontSize.value - 2).clamp(10, 32);
  void toggleLineWrap() => lineWrap.value = !lineWrap.value;

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
    final target = (lineIndex * _approxLineHeight).clamp(0.0, scrollController.position.maxScrollExtent);
    scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  bool get isFavorite => _interactions.isFavorite(document.id);
  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);
  Future<void> share() => _interactions.shareDocument(document);
  Future<void> openWith() => _interactions.openWithExternalApp(document);

  @override
  void onClose() {
    _positionSaveDebounce?.cancel();
    if (scrollController.hasClients && scrollController.offset > 0) {
      unawaited(_savePosition(scrollController.offset));
    }
    scrollController.dispose();
    super.onClose();
  }
}
