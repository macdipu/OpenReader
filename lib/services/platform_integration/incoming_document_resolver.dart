import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';
import 'package:path/path.dart' as p;

import '../../core/data/repositories/document_repository_impl.dart';
import '../../core/domain/models/document_category.dart';
import '../../core/domain/models/document_model.dart';
import '../../core/domain/repositories/document_repository.dart';
import '../../core/presentation/utils/logger.dart';

/// What happened when [IncomingDocumentResolver.resolve] processed a raw
/// path handed to OpenReader by another app.
enum IncomingDocumentOutcome {
  /// Indexed and ready to open - [IncomingDocumentResolution.document] is set.
  success,

  /// The extension has no reader (BRD §13 "Unsupported format").
  unsupported,

  /// The path doesn't exist or couldn't be read/indexed (BRD §13 "File
  /// missing"/"Corrupted file" - treated the same here since, at this point,
  /// there is no original index entry to distinguish "deleted" from "never
  /// existed").
  inaccessible,
}

class IncomingDocumentResolution {
  final DocumentModel? document;
  final IncomingDocumentOutcome outcome;

  const IncomingDocumentResolution._(this.document, this.outcome);

  const IncomingDocumentResolution.success(DocumentModel document) : this._(document, IncomingDocumentOutcome.success);
  const IncomingDocumentResolution.unsupported() : this._(null, IncomingDocumentOutcome.unsupported);
  const IncomingDocumentResolution.inaccessible() : this._(null, IncomingDocumentOutcome.inaccessible);
}

/// Resolves a raw file path handed to OpenReader by another app (BRD §7.7,
/// TASK-009) into an indexed [DocumentModel] ready to open, or a reason it
/// can't be.
///
/// Kept separate from the platform-channel wiring (`IncomingIntentService`)
/// so this logic - category checking, indexing - is unit-testable without a
/// real Android intent, which this environment has no emulator to deliver
/// anyway.
///
/// Indexing before open is not a nicety: `recent_documents.document_id` is a
/// foreign key into `documents` with `ON DELETE CASCADE` and
/// `PRAGMA foreign_keys = ON` (`app_database.dart`), so a reader's own
/// `markOpened()` call would throw a foreign-key-constraint error for a file
/// that was never indexed. Confirmed by reading the schema, not assumed.
class IncomingDocumentResolver {
  final DocumentRepository _documentRepository;

  IncomingDocumentResolver({DocumentRepository? documentRepository}) : _documentRepository = documentRepository ?? DocumentRepositoryImpl();

  /// Extension of [path] with any URL query/fragment removed first.
  ///
  /// Messaging apps hand over `content://` URIs like
  /// `content://com.facebook.orca.securefileprovider/temp/Doc.pdf?s=1`, where
  /// `p.extension()` would yield `pdf?s=1` and the document would look
  /// unsupported even though its name ends in `.pdf`.
  @visibleForTesting
  static String extensionOf(String path) {
    final cleaned = path.split('?').first.split('#').first;
    return p.extension(cleaned).replaceFirst('.', '').toLowerCase();
  }

  /// [displayName] is the name the sending app gave the file. A `content://` share is copied to a
  /// cache file whose own name carries a lookup prefix, so the path's basename is only the fallback.
  Future<IncomingDocumentResolution> resolve(String path, {String? mimeType, String? displayName}) async {
    var extension = extensionOf(path);
    var category = DocumentCategory.fromExtension(extension);
    final extensionFromPath = extension;
    if (category == DocumentCategory.unknown && mimeType != null) {
      // The sharing plugin names some `content://` copies `<prefix>_<time>.null`,
      // so the MIME type is the only clue to what they are.
      final fromMime = DocumentFormat.extensionForMimeType(mimeType);
      if (fromMime != null) {
        extension = fromMime;
        category = DocumentCategory.fromExtension(fromMime);
      }
    }
    AppLogger.info(
      '[INTENT] resolve: path="$path" mime=$mimeType '
      'extensionFromPath="${extensionFromPath.isEmpty ? '<none>' : extensionFromPath}" '
      'extension="$extension" category=${category.name}',
    );

    if (category == DocumentCategory.unknown) {
      return const IncomingDocumentResolution.unsupported();
    }

    final FileStat stat;
    try {
      stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) {
        return const IncomingDocumentResolution.inaccessible();
      }
    } catch (_) {
      return const IncomingDocumentResolution.inaccessible();
    }

    final document = DocumentModel(
      id: path,
      path: path,
      displayName: (displayName != null && displayName.isNotEmpty) ? displayName : p.basename(path),
      extension: extension,
      category: category,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      lastSeenAt: DateTime.now(),
    );

    final result = await _documentRepository.indexDocument(document);
    return result.fold(
      (failure) {
        AppLogger.error('[INTENT] indexing failed for "$path": ${failure.message}');
        return const IncomingDocumentResolution.inaccessible();
      },
      (indexed) => IncomingDocumentResolution.success(indexed),
    );
  }
}
