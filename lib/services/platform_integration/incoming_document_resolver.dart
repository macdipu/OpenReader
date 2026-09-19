import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/data/repositories/document_repository_impl.dart';
import '../../core/domain/models/document_category.dart';
import '../../core/domain/models/document_model.dart';
import '../../core/domain/repositories/document_repository.dart';

/// What happened when [IncomingDocumentResolver.resolve] processed a raw
/// path handed to OpenReader by another app.
enum IncomingDocumentOutcome {
  /// Indexed and ready to open - [IncomingDocumentResolution.document] is set.
  success,

  /// The extension has no reader (BRD §13 "Unsupported format") - includes
  /// PowerPoint, which has no reader yet either (`FEATURE-OPENREADER-P3`).
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

  Future<IncomingDocumentResolution> resolve(String path) async {
    final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
    final category = DocumentCategory.fromExtension(extension);

    if (category == DocumentCategory.unknown || category == DocumentCategory.powerpoint) {
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
      displayName: p.basename(path),
      extension: extension,
      category: category,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      lastSeenAt: DateTime.now(),
    );

    final result = await _documentRepository.indexDocument(document);
    return result.fold(
      (failure) => const IncomingDocumentResolution.inaccessible(),
      (indexed) => IncomingDocumentResolution.success(indexed),
    );
  }
}
