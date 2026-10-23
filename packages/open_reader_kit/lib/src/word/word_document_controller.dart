import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../common/reader_contract.dart';
import '../common/zip_safety_guard.dart';
import '../engines/docx/viewer/docx_file_viewer.dart';

/// State for [WordDocumentView]: a `.docx` checked by [ZipSafetyGuard],
/// search within it, and the scroll position.
///
/// The Word engine's view has no scroll-controller or initial-offset
/// parameter, but its vertical scroll view has no controller of its own,
/// so it adopts the nearest `PrimaryScrollController`. [WordDocumentView]
/// provides [scrollController] that way, which is how the position is both
/// restored ([onDocumentLoaded]) and reported ([onScrollOffsetChanged] →
/// [onPositionChanged] as `{scroll_offset}`); saving it is the app's
/// business.
class WordDocumentController extends ChangeNotifier {
  WordDocumentController({ReadingPosition? initialPosition, this.onPositionChanged})
      : initialScrollOffset = switch (initialPosition?[PositionKeys.scrollOffset]) {
          final num offset when offset > 0 => offset.toDouble(),
          _ => 0,
        };

  /// Where the document scrolls to once loaded. Settable until then, for an
  /// app that reads the saved position after creating the controller.
  double initialScrollOffset;

  final ValueChanged<ReadingPosition>? onPositionChanged;

  final searchController = DocxSearchController();
  final scrollController = ScrollController();

  bool _disposed = false;

  DocumentLoadError? _error;
  DocumentLoadError? get error => _error;

  Uint8List? _bytes;

  /// The checked bytes [WordDocumentView] renders; null until [load]
  /// accepts them.
  Uint8List? get validatedBytes => _bytes;

  /// Checks [bytes] with [ZipSafetyGuard] before the engine decompresses
  /// anything.
  void load(Uint8List bytes) {
    switch (ZipSafetyGuard.check(bytes)) {
      case ZipSafetyResult.safe:
        _bytes = bytes;
      case ZipSafetyResult.tooLarge:
        _error = DocumentLoadError.tooLarge;
      case ZipSafetyResult.corrupted:
        _error = DocumentLoadError.corrupted;
    }
    notifyListeners();
  }

  /// The engine's `onError`: the package passed the ZIP check but the
  /// document itself couldn't be read.
  void onLoadError(Object error) {
    _error ??= DocumentLoadError.corrupted;
    notifyListeners();
  }

  /// The engine's `onLoaded`: once laid out, jump to the saved offset
  /// (clamped - the document may have changed).
  void onDocumentLoaded() {
    if (initialScrollOffset <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !scrollController.hasClients) return;
      final position = scrollController.position;
      scrollController.jumpTo(initialScrollOffset.clamp(0.0, position.maxScrollExtent));
    });
  }

  /// The view reports the document's own vertical scroll here.
  void onScrollOffsetChanged(double offset) => onPositionChanged?.call({PositionKeys.scrollOffset: offset});

  void search(String query) => searchController.search(query);
  void clearSearch() => searchController.clear();
  void nextMatch() => searchController.nextMatch();
  void previousMatch() => searchController.previousMatch();

  @override
  void dispose() {
    _disposed = true;
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
