import 'dart:io';

import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/services/platform_integration/incoming_document_resolver.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class FixtureDocumentRepository implements DocumentRepository {
  DocumentModel? indexed;
  bool failIndexing = false;

  @override
  ResultFuture<DocumentModel> indexDocument(DocumentModel document) async {
    if (failIndexing) return const Left(LocalDatabaseQueryFailure('boom'));
    indexed = document;
    return Right(document);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late FixtureDocumentRepository repository;
  late IncomingDocumentResolver resolver;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('openreader-incoming-');
    repository = FixtureDocumentRepository();
    resolver = IncomingDocumentResolver(documentRepository: repository);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('resolves and indexes a supported file (BRD §7.7 steps 3-5)', () async {
    final file = File(p.join(root.path, 'shared.pdf'));
    await file.writeAsBytes([1, 2, 3, 4]);

    final resolution = await resolver.resolve(file.path);

    expect(resolution.outcome, IncomingDocumentOutcome.success);
    expect(resolution.document?.category, DocumentCategory.pdf);
    expect(resolution.document?.displayName, 'shared.pdf');
    expect(resolution.document?.sizeBytes, 4);
    expect(repository.indexed?.path, file.path);
  });

  test('extension matching is case-insensitive', () async {
    final file = File(p.join(root.path, 'SHARED.XLSX'));
    await file.writeAsBytes([1]);

    final resolution = await resolver.resolve(file.path);

    expect(resolution.outcome, IncomingDocumentOutcome.success);
    expect(resolution.document?.category, DocumentCategory.excel);
  });

  test('rejects a genuinely unsupported extension without indexing (BRD §13 "Unsupported format")', () async {
    final file = File(p.join(root.path, 'archive.zip'));
    await file.writeAsBytes([1]);

    final resolution = await resolver.resolve(file.path);

    expect(resolution.outcome, IncomingDocumentOutcome.unsupported);
    expect(repository.indexed, isNull);
  });

  test('rejects PowerPoint since no reader exists yet, even though the category itself is recognized', () async {
    final file = File(p.join(root.path, 'deck.pptx'));
    await file.writeAsBytes([1]);

    final resolution = await resolver.resolve(file.path);

    expect(resolution.outcome, IncomingDocumentOutcome.unsupported);
    expect(repository.indexed, isNull);
  });

  test('reports inaccessible for a path that does not exist, without indexing', () async {
    final resolution = await resolver.resolve(p.join(root.path, 'missing.pdf'));

    expect(resolution.outcome, IncomingDocumentOutcome.inaccessible);
    expect(repository.indexed, isNull);
  });

  test('reports inaccessible when indexing itself fails', () async {
    repository.failIndexing = true;
    final file = File(p.join(root.path, 'shared.txt'));
    await file.writeAsBytes([1]);

    final resolution = await resolver.resolve(file.path);

    expect(resolution.outcome, IncomingDocumentOutcome.inaccessible);
    expect(resolution.document, isNull);
  });
}
