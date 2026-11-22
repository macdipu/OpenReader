import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:universal_document_viewer/ocr.dart';

/// What a recognition has found so far, for the live scan on the page: the lines merged from what has
/// been read up to now, in image pixels of [imageSize].
@immutable
class OcrProgress {
  const OcrProgress({
    required this.done,
    required this.total,
    required this.lines,
    required this.imageSize,
  });

  /// Parts of the reading finished so far (scripts, for ML Kit), of [total].
  final int done;
  final int total;

  /// The merged lines found so far.
  final List<OcrLine> lines;

  /// The size of the image the line rectangles are in.
  final Size imageSize;

  /// 0 to 1.
  double get fraction => total == 0 ? 0 : done / total;
}
