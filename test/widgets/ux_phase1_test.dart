import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/features/search/presentation/search_controller.dart';
import 'package:openreader/features/search/presentation/search_view.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_controller.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_view.dart';

/// CR-OPENREADER-UX Phase 1 regressions (UX1-AC4…AC7).

final sample = DocumentModel(
  id: '/fixtures/report.txt',
  path: '/fixtures/report.txt',
  displayName: 'report.txt',
  extension: 'txt',
  category: DocumentCategory.text,
  sizeBytes: 10,
  modifiedAt: DateTime(2026),
  lastSeenAt: DateTime(2026),
);

class FixtureDocuments implements DocumentRepository {
  @override
  ResultFuture<List<DocumentModel>> getDocuments(
          {DocumentCategory? category, String? query, DocumentSortMode sort = DocumentSortMode.nameAsc}) async =>
      Right([sample]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  @override
  ResultFuture<Map<String, Object?>> getPosition(String documentId) async => const Right({});
  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async =>
      const Right(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: FixtureRecents()));
  });
  tearDown(Get.reset);

  testWidgets('Search clear empties the field and resets results (UX1-AC4)', (tester) async {
    final controller = Get.put(SearchDocumentsController(documentRepository: FixtureDocuments()));
    await tester.pumpWidget(const GetMaterialApp(home: SearchView()));
    await tester.enterText(find.byType(TextField), 'rep');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('report.txt'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(controller.status.value, StateStatus.initial);
    expect(find.text('Search documents by filename.'), findsOneWidget);
  });

  testWidgets('Reader app bar only grows while searching; zero matches say "No matches" (UX1-AC5/AC7)',
      (tester) async {
    final controller = Get.put(TextReaderController(
      document: sample,
      recentRepository: FixtureRecents(),
      interactions: Get.find<DocumentInteractionController>(),
    ));
    await tester.pumpWidget(const GetMaterialApp(home: TextReaderView()));
    // The reader's file read is real I/O (the fixture path doesn't exist, so
    // it ends in the error state); it can't complete inside fake async.
    for (var i = 0; i < 50 && controller.status.value.isBusy; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pumpAndSettle();
    expect(controller.status.value, StateStatus.error);
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight + 40);

    await tester.enterText(find.byType(TextField), 'absent');
    await tester.pumpAndSettle();
    expect(controller.matches, isEmpty);
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('No searchable text found.'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });

  test('legacy .doc/.xls are not supported formats; .docx/.xlsx unchanged (UX1-AC6)', () {
    for (final legacy in ['doc', 'xls', 'DOC', 'XLS']) {
      expect(DocumentCategory.fromExtension(legacy), DocumentCategory.unknown, reason: legacy);
    }
    expect(DocumentCategory.supportedExtensions, isNot(contains('doc')));
    expect(DocumentCategory.supportedExtensions, isNot(contains('xls')));
    expect(DocumentCategory.fromExtension('docx'), DocumentCategory.word);
    expect(DocumentCategory.fromExtension('xlsx'), DocumentCategory.excel);
  });
}
