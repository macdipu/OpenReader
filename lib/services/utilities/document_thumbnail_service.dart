import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';

import '../../core/domain/models/document_model.dart';
import 'path_service.dart';

/// Draws [path]'s first page - or the page [position] is on - as PNG bytes
/// [width] pixels wide; null when it can't.
typedef ThumbnailRender = Future<Uint8List?> Function(String path, {required int width, ReadingPosition? position});

/// Renders and disk-caches a small first-page preview for every format
/// the kit reads - PDF, Word, Excel, CSV, PowerPoint and text - via
/// universal_document_viewer's [DocumentThumbnails] (DocumentListTile thumbnail +
/// format-badge overlay). Never throws - callers fall back to the plain
/// badge when this returns null.
///
/// Given a reading position, the preview is of the page reading resumes
/// on (Continue Reading, recent rows), cached per page: scrolling within a
/// page doesn't redraw it.
class DocumentThumbnailService {
  DocumentThumbnailService._({
    PathService? pathService,
    ThumbnailRender? render,
    this.failureRetryAfter = const Duration(seconds: 30),
    this.maxCachedFiles = 500,
  })  : _pathService = pathService ?? PathService.instance,
        _render = render ?? DocumentThumbnails.render;

  /// For tests: a fake temp directory and/or renderer, and the retry and
  /// pruning limits.
  @visibleForTesting
  DocumentThumbnailService.withDependencies({
    PathService? pathService,
    ThumbnailRender? render,
    Duration failureRetryAfter = const Duration(seconds: 30),
    int maxCachedFiles = 500,
  }) : this._(
          pathService: pathService,
          render: render,
          failureRetryAfter: failureRetryAfter,
          maxCachedFiles: maxCachedFiles,
        );

  static final DocumentThumbnailService instance = DocumentThumbnailService._();

  final PathService _pathService;
  final ThumbnailRender _render;

  static const _thumbnailWidth = 160;

  /// Part of the cache key: bump it when thumbnails start to look
  /// different, so previews cached by an older build are redrawn.
  static const _renderVersion = 2;

  /// How long a document with no preview (damaged, too large, still being
  /// copied...) is answered with null before it's tried again - so a list
  /// rebuilding doesn't re-parse it every frame, yet a file that becomes
  /// readable gets its preview in the same session.
  final Duration failureRetryAfter;

  /// Most previews kept on disk; past it, the oldest are deleted.
  final int maxCachedFiles;

  /// In-memory dedupe so scrolling the same row repeatedly doesn't queue a
  /// second render while the first is still in flight. An entry is dropped
  /// once it completes: the on-disk file is the real cache (and survives
  /// across app restarts), and keeping the future would keep serving a file
  /// that was since pruned or a null that was only transient.
  final _inFlight = <String, Future<File?>>{};

  /// When each request last came back null, for [failureRetryAfter].
  final _failedAt = <String, DateTime>{};

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
    // With the modified time, so an edited file isn't answered from a
    // request made before the edit.
    final key = '${document.id}|${document.modifiedAt.millisecondsSinceEpoch}|$pageKey';
    if (_inFlight[key] case final pending?) return pending;
    if (_failedAt[key] case final failed? when DateTime.now().difference(failed) < failureRetryAfter) {
      return Future.value();
    }
    final request = _renderOrLoadFromCache(document, page.isEmpty ? null : page, pageKey).then((file) {
      _inFlight.remove(key);
      if (file == null) {
        _failedAt[key] = DateTime.now();
      } else {
        _failedAt.remove(key);
      }
      return file;
    });
    return _inFlight[key] = request;
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
      final modified = document.modifiedAt.millisecondsSinceEpoch;
      final cacheKey = cacheFileName('${document.id}_${modified}_v$_renderVersion$page');
      final cacheFile = File('${thumbnailDir.path}/$cacheKey.png');
      if (await cacheFile.exists()) return cacheFile;

      final png = await _render(document.path, width: _thumbnailWidth, position: position);
      if (png == null) return null;
      // Written aside and renamed into place, so an app killed mid-write
      // leaves a stray .tmp, never a truncated .png served from then on.
      final partial = File('${cacheFile.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await partial.writeAsBytes(png, flush: true);
      await partial.rename(cacheFile.path);
      await _prune(thumbnailDir);
      return cacheFile;
    } catch (_) {
      return null;
    }
  }

  /// Deletes the oldest files past [maxCachedFiles]: a preview per document,
  /// edit and resumed page would otherwise pile up for as long as the OS
  /// leaves the temp directory alone.
  Future<void> _prune(Directory dir) async {
    final files = await dir.list().where((entry) => entry is File).cast<File>().toList();
    if (files.length <= maxCachedFiles) return;
    final byAge = [for (final file in files) (file, (await file.stat()).modified)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (file, _) in byAge.take(files.length - maxCachedFiles)) {
      try {
        await file.delete();
      } on FileSystemException {
        // Already gone (another prune), or in use: the next prune retries.
      }
    }
  }

  /// A 64-bit FNV-1a hash of [key] as 16 hex digits: stable across runs
  /// and builds (unlike [String.hashCode], which is also only 30 bits on
  /// some platforms - enough previews in one directory to collide), and
  /// file-name safe.
  @visibleForTesting
  static String cacheFileName(String key) {
    var hash = -0x340d631b7bdddcdb; // 0xcbf29ce484222325, the FNV offset basis, as a signed 64-bit int.
    for (final byte in utf8.encode(key)) {
      hash = (hash ^ byte) * 0x100000001b3; // Wraps mod 2^64, as FNV wants.
    }
    String half(int bits) => bits.toRadixString(16).padLeft(8, '0');
    return half((hash >> 32) & 0xFFFFFFFF) + half(hash & 0xFFFFFFFF);
  }
}
