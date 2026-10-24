import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:open_reader_kit/pdf.dart';

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

  /// Bumped when previews are rendered differently. 2: the whole first page
  /// (open_reader_kit's own engine); 1 kept only the top-left corner.
  static const _renderVersion = 2;

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
      // (same path, new content) doesn't serve a stale cached preview, and by
      // [_renderVersion], so previews from an older renderer are replaced.
      final cacheKey = '$_renderVersion:${document.id}_${document.modifiedAt.millisecondsSinceEpoch}'.hashCode;
      final cacheFile = File('${thumbnailDir.path}/$cacheKey.png');
      if (await cacheFile.exists()) return cacheFile;

      return await _render(document, cacheFile);
    } catch (_) {
      return null;
    }
  }

  /// The whole first page scaled down to [_thumbnailWidth] (the old
  /// engine's call rendered at 72 dpi and kept only the top-left corner).
  Future<File?> _render(DocumentModel document, File cacheFile) async {
    final doc = await PdfiumDocument.openFile(document.path);
    try {
      if (doc.pageCount == 0 || doc.pageSizes.first.width <= 0) return null;
      final rendered = await doc.renderThumbnail(0, width: _thumbnailWidth);
      final image = await rendered.toImage();
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return null;
        await cacheFile.writeAsBytes(byteData.buffer.asUint8List());
        return cacheFile;
      } finally {
        image.dispose();
      }
    } finally {
      await doc.close();
    }
  }
}
