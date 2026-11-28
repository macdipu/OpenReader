import 'package:get/get.dart';

/// Turning the view of a reader whose document reflows or scrolls (Word, text, Markdown, sheets,
/// slides) by quarter turns. The document itself is not changed, and nothing is saved: the next time
/// it opens it is upright. A PDF turns its pages in the engine instead (`PdfController.rotate`).
/// [ReaderRotated] draws it.
mixin ReaderRotation on GetxController {
  /// Quarter turns clockwise, 0-3.
  final quarterTurns = 0.obs;

  void rotateClockwise() => quarterTurns.value = (quarterTurns.value + 1) & 3;

  void rotateCounterclockwise() => quarterTurns.value = (quarterTurns.value + 3) & 3;
}
