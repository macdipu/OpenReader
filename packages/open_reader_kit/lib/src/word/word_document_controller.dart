import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../common/reader_contract.dart';
import '../common/zip_safety_guard.dart';
import '../engines/word/docx_reader.dart';
import '../engines/word/word_model.dart';
import 'word_document_layout.dart';
import 'word_search_controller.dart';

/// State for [WordDocumentView]: a `.docx` checked by [ZipSafetyGuard] and
/// parsed off the UI isolate, search within it, and the scroll position.
///
/// The position is reported through [onPositionChanged] as
/// `{scroll_offset}`; saving it (and debouncing) is the app's business.
class WordDocumentController extends ChangeNotifier {
  WordDocumentController({ReadingPosition? initialPosition, this.onPositionChanged})
      : initialScrollOffset = switch (initialPosition?[PositionKeys.scrollOffset]) {
          final num offset when offset > 0 => offset.toDouble(),
          _ => 0,
        };

  /// Where the document scrolls to once shown. Settable until then, for an
  /// app that reads the saved position after creating the controller.
  double initialScrollOffset;

  final ValueChanged<ReadingPosition>? onPositionChanged;

  final searchController = WordSearchController();
  final scrollController = ScrollController();

  bool _disposed = false;

  bool _loaded = false;

  /// True once [load] finished, successfully or not.
  bool get isLoaded => _loaded;

  DocumentLoadError? _error;
  DocumentLoadError? get error => _error;

  WordDocumentLayout? _layout;

  /// The parsed document laid out for display; null until [load] succeeds.
  WordDocumentLayout? get layout => _layout;
  WordDocument? get document => _layout?.document;

  /// Checks [bytes] with [ZipSafetyGuard], then parses them in a background
  /// isolate.
  Future<void> load(Uint8List bytes) async {
    switch (ZipSafetyGuard.check(bytes)) {
      case ZipSafetyResult.tooLarge:
        _error = DocumentLoadError.tooLarge;
      case ZipSafetyResult.corrupted:
        _error = DocumentLoadError.corrupted;
      case ZipSafetyResult.safe:
        try {
          final document = await Isolate.run(() => DocxReader.read(bytes));
          if (_disposed) return;
          final layout = WordDocumentLayout(document);
          _layout = layout;
          searchController.setParagraphs([for (final p in layout.paragraphs) p.plainText]);
        } catch (_) {
          _error = DocumentLoadError.corrupted;
        }
    }
    if (_disposed) return;
    _loaded = true;
    notifyListeners();
  }

  /// For a caller whose own read failed (e.g. the file vanished).
  void rejectAsCorrupted() {
    _error = DocumentLoadError.corrupted;
    _loaded = true;
    notifyListeners();
  }

  /// The view reports the document's vertical scroll here.
  void onScrollOffsetChanged(double offset) => onPositionChanged?.call({PositionKeys.scrollOffset: offset});

  void search(String query) => searchController.search(query);
  void clearSearch() => searchController.clear();
  void nextMatch() => searchController.next();
  void previousMatch() => searchController.previous();

  @override
  void dispose() {
    _disposed = true;
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
