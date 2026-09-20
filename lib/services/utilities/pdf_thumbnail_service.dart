import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import '../../core/domain/models/document_model.dart';
import 'path_service.dart';

/// Renders and disk-caches a small first-page preview for PDF documents
/// (DocumentListTile thumbnail + format-badge overlay). Never throws -
/// callers fall back to the plain badge when this returns null.
class PdfThumbnailService {
  PdfThumbnailService._({PathService? pathService}) : _pathService = pathService ?? PathService.instance;

  static final PdfThumbnailService instance = PdfThumbnailService._();

  final PathService _pathService;

  static const _thumbnailWidth = 160;

  /// In-memory dedupe so scrolling the same row repeatedly doesn't queue a
  /// second render while the first is still in flight; the on-disk file is
  /// the real cache and survives across app restarts.
  final _inFlight = <String, Future<File?>>{};

  Future<File?> getThumbnail(DocumentModel document) {
    return _inFlight.putIfAbsent(document.id, () => _renderOrLoadFromCache(document));
  }

  Future<File?> _renderOrLoadFromCache(DocumentModel document) async {
    try {
      final tempResult = await _pathService.getTempDirectory();
      final tempDir = tempResult.fold((_) => null, (dir) => dir);
      if (tempDir == null) return null;

      final thumbnailDir = Directory('${tempDir.path}/pdf_thumbnails');
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      // Keyed by path + modified time, so an edited/replaced file on disk
      // (same path, new content) doesn't serve a stale cached preview.
      final cacheKey = '${document.id}_${document.modifiedAt.millisecondsSinceEpoch}'.hashCode;
      final cacheFile = File('${thumbnailDir.path}/$cacheKey.png');
      if (await cacheFile.exists()) return cacheFile;

      return await _render(document, cacheFile);
    } catch (_) {
      return null;
    }
  }

  Future<File?> _render(DocumentModel document, File cacheFile) async {
    final doc = await PdfDocument.openFile(document.path);
    try {
      if (doc.pages.isEmpty) return null;
      final page = doc.pages.first;
      if (page.width <= 0) return null;

      final scale = _thumbnailWidth / page.width;
      const width = _thumbnailWidth;
      final height = (page.height * scale).round().clamp(1, 4000);

      final image = await page.render(width: width, height: height);
      if (image == null) return null;
      try {
        final uiImage = await _decode(image);
        try {
          final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) return null;
          await cacheFile.writeAsBytes(byteData.buffer.asUint8List());
          return cacheFile;
        } finally {
          uiImage.dispose();
        }
      } finally {
        image.dispose();
      }
    } finally {
      await doc.dispose();
    }
  }

  Future<ui.Image> _decode(PdfImage image) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      image.pixels,
      image.width,
      image.height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }
}
