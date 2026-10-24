import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_reader_kit/open_reader_kit.dart';

import '../../core/domain/models/document_model.dart';
import 'path_service.dart';

/// Draws [path]'s first page - or the page [position] is on - as PNG bytes
/// [width] pixels wide; null when it can't.
typedef ThumbnailRender = Future<Uint8List?> Function(String path, {required int width, ReadingPosition? position});

/// Renders and disk-caches a small first-page preview for every format
/// the kit reads - PDF, Word, Excel, CSV, PowerPoint and text - via
/// open_reader_kit's [DocumentThumbnails] (DocumentListTile thumbnail +
/// format-badge overlay). Never throws - callers fall back to the plain
/// badge when this returns null.
///
/// Given a reading position, the preview is of the page reading resumes
/// on (Continue Reading, recent rows), cached per page: scrolling within a
/// page doesn't redraw it.
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

  /// The position keys that pick the page a thumbnail shows; the rest
  /// (scroll offsets, zoom, view mode) move within it.
  static const _pageKeys = [
    PositionKeys.pageNumber,
    PositionKeys.paragraph,
    PositionKeys.slideIndex,
    PositionKeys.sheetIndex,
    PositionKeys.row,
    PositionKeys.column,
    PositionKeys.line,
  ];

  Future<File?> getThumbnail(DocumentModel document, {ReadingPosition? position}) {
    final page = <String, Object?>{
      for (final key in _pageKeys)
        if (position?[key] case final value?) key: value,
    };
    final pageKey = [for (final MapEntry(:key, :value) in page.entries) '$key=$value'].join(',');
    return _inFlight.putIfAbsent(
      '${document.id}|$pageKey',
      () => _renderOrLoadFromCache(document, page.isEmpty ? null : page, pageKey),
    );
  }

  Future<File?> _renderOrLoadFromCache(DocumentModel document, ReadingPosition? position, String pageKey) async {
    try {
      final tempResult = await _pathService.getTempDirectory();
      final tempDir = tempResult.fold((_) => null, (dir) => dir);
      if (tempDir == null) return null;

      final thumbnailDir = Directory('${tempDir.path}/document_thumbnails');
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      // Keyed by path + modified time, so an edited/replaced file on disk
      // (same path, new content) doesn't serve a stale cached preview, and
      // by the page shown.
      final page = pageKey.isEmpty ? '' : '_$pageKey';
      final cacheKey = '${document.id}_${document.modifiedAt.millisecondsSinceEpoch}_v$_renderVersion$page'.hashCode;
      final cacheFile = File('${thumbnailDir.path}/$cacheKey.png');
      if (await cacheFile.exists()) return cacheFile;

      final png = await _render(document.path, width: _thumbnailWidth, position: position);
      if (png == null) return null;
      await cacheFile.writeAsBytes(png);
      return cacheFile;
    } catch (_) {
      return null;
    }
  }
}
