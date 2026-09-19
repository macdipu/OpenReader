import 'dart:io';

import '../../core/domain/models/document_category.dart';
import '../../core/domain/models/document_model.dart';
import '../../core/presentation/utils/logger.dart';

/// Walks accessible local storage for supported document files (BRD 7.1).
///
/// Scoped to the shared/public roots most user documents land in, rather
/// than a full-device walk: that keeps a rescan fast and avoids wandering
/// into Android/data sandboxed app directories the OS hides anyway.
///
/// Named `FileScannerService` (not `DocumentScannerService`) to leave that
/// name free for a future camera-based document scanner feature.
class FileScannerService {
  FileScannerService({Iterable<String> roots = _rootCandidates})
      : _roots = List.unmodifiable(roots);

  static final FileScannerService instance = FileScannerService();
  final List<String> _roots;

  static const _rootCandidates = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
    '/storage/emulated/0',
  ];

  static const _maxDepth = 8;

  Future<List<DocumentModel>> scan() async {
    final found = <String, DocumentModel>{};
    final now = DateTime.now();

    for (final rootPath in _roots) {
      final root = Directory(rootPath);
      if (!await root.exists()) continue;
      await _walk(root, depth: 0, now: now, into: found);
    }

    return found.values.toList();
  }

  Future<void> _walk(
    Directory directory, {
    required int depth,
    required DateTime now,
    required Map<String, DocumentModel> into,
  }) async {
    if (depth > _maxDepth) return;

    List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } catch (e) {
      AppLogger.warning('Skipping unreadable directory ${directory.path}: $e');
      return;
    }

    for (final entity in entries) {
      if (entity is Directory) {
        await _walk(entity, depth: depth + 1, now: now, into: into);
        continue;
      }
      if (entity is! File) continue;
      if (into.containsKey(entity.path)) continue;

      final extension = _extensionOf(entity.path);
      final category = DocumentCategory.fromExtension(extension);
      if (category == DocumentCategory.unknown) continue;

      try {
        final stat = await entity.stat();
        if (stat.size <= 0) continue;
        into[entity.path] = DocumentModel(
          id: entity.path,
          path: entity.path,
          displayName: _nameOf(entity.path),
          extension: extension,
          category: category,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          lastSeenAt: now,
        );
      } catch (e) {
        AppLogger.warning('Skipping unreadable file ${entity.path}: $e');
      }
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }

  String _nameOf(String path) {
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }
}
