import 'dart:ui' as ui;

/// Draws the first page of one document format for [DocumentThumbnails].
///
/// [render] returns an image exactly [width] pixels wide, as tall as the
/// page's aspect ratio makes it, or null when the file has nothing to show.
/// It may throw on a damaged file: [DocumentThumbnails] turns any failure
/// into null for its callers.
abstract interface class ThumbnailRenderer {
  Future<ui.Image?> render(String path, {required int width});
}
