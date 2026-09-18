import 'dart:io';

import '../../core/domain/models/document_category.dart';

/// Fresh, non-persisted filesystem metadata for the File Information screen
/// (BRD 9.16, ODF-010). Re-stats the file rather than trusting the indexed
/// `DocumentModel`, which may be stale since the last scan.
///
/// Deliberately does not include a created date or reader-derived counts
/// (page/sheet/slide count): Android's [FileStat.changed] is inode-change
/// time, not creation time, and counts need a reader's own parser, which
/// doesn't exist yet. BRD 9.16 lists "Metadata unavailable" as an accepted
/// corner case, so the File Information screen shows those as explicitly
/// not available rather than a wrong or fabricated value.
class FileMetadata {
  final String path;
  final String extension;
  final DocumentCategory category;
  final int sizeBytes;
  final DateTime modifiedAt;

  const FileMetadata({
    required this.path,
    required this.extension,
    required this.category,
    required this.sizeBytes,
    required this.modifiedAt,
  });
}

class FileMetadataService {
  FileMetadataService._();
  static final FileMetadataService instance = FileMetadataService._();

  /// Returns null if the file no longer exists (BRD 9.16 corner case:
  /// "File deleted after info screen opened").
  Future<FileMetadata?> read({
    required String path,
    required String extension,
    required DocumentCategory category,
  }) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    return FileMetadata(
      path: path,
      extension: extension,
      category: category,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }
}
