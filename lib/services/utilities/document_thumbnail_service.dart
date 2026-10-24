import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_reader_kit/open_reader_kit.dart';

import '../../core/domain/models/document_model.dart';
import 'path_service.dart';

/// Draws [path]'s first page as PNG bytes [width] pixels wide; null when it
/// can't.
typedef ThumbnailRender = Future<Uint8List?> Function(String path, {required int width});

/// Renders and disk-caches a small first-page preview for every format
/// the kit reads - PDF, Word, Excel, CSV, PowerPoint and text - via
/// open_reader_kit's [DocumentThumbnails] (DocumentListTile thumbnail +
/// format-badge overlay). Never throws - callers fall back to the plain
/// badge when this returns null.
class DocumentThumbnailService {
  DocumentThumbnailService._({PathService? pathService, ThumbnailRender? render})
      : _pathService = pathService ?? PathService.instance,
        _render = render ?? DocumentThumbnails.render;

  /// For tests: a fake temp directory and/or renderer.
  @visibleForTesting
  DocumentThumbnailService.withDependencies({PathService? pathService, ThumbnailRender? render})
      : this._(pathService: pathService, render: render);

  static final DocumentThumbnailService instance = DocumentThumbnailService._();

  final PathService _pathService;
  final ThumbnailRender _render;

  static const _thumbnailWidth = 160;

  /// Part of the cache key: bump it when thumbnails start to look
  /// different, so previews cached by an older build are redrawn.
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

      final thumbnailDir = Directory('${tempDir.path}/document_thumbnails');
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      // Keyed by path + modified time, so an edited/replaced file on disk
      // (same path, new content) doesn't serve a stale cached preview.
      final cacheKey = '${document.id}_${document.modifiedAt.millisecondsSinceEpoch}_v$_renderVersion'.hashCode;
      final cacheFile = File('${thumbnailDir.path}/$cacheKey.png');
      if (await cacheFile.exists()) return cacheFile;

      final png = await _render(document.path, width: _thumbnailWidth);
      if (png == null) return null;
      await cacheFile.writeAsBytes(png);
      return cacheFile;
    } catch (_) {
      return null;
    }
  }
}
