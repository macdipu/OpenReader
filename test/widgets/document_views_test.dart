import 'dart:async';

import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/models/recent_document_model.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/base_controller.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/core/presentation/widgets/loading_view/loading_view.dart';
import 'package:openreader/features/files/presentation/files_controller.dart';
import 'package:openreader/features/files/presentation/files_view.dart';
import 'package:openreader/features/home/presentation/home_controller.dart';
import 'package:openreader/features/home/presentation/home_view.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

final sample = DocumentModel(
  id: '/fixtures/report.pdf',
  path: '/fixtures/report.pdf',
  displayName: 'report.pdf',
  extension: 'pdf',
  category: DocumentCategory.pdf,
  sizeBytes: 100,
  modifiedAt: DateTime(2026),
  lastSeenAt: DateTime(2026),
);

class FixtureDocuments implements DocumentRepository {
  List<DocumentModel> items = [];
  bool failLoad = false;
  bool failScan = false;
  int loadCalls = 0;
  int scanCalls = 0;
  DocumentCategory? category;
  String? query;
  DocumentSortMode? sort;
  @override
  ResultFuture<List<DocumentModel>> getDocuments(
      {DocumentCategory? category,
      String? query,
      DocumentSortMode sort = DocumentSortMode.nameAsc}) async {
    loadCalls++;
    this.category = category;
    this.query = query;
    this.sort = sort;
    return failLoad
        ? const Left(ServerFailure('Could not load documents'))
        : Right(items);
  }

  @override
  ResultFuture<int> countByCategory(DocumentCategory category) async {
    loadCalls++;
    return failLoad
        ? const Left(ServerFailure('Could not load documents'))
        : Right(items.where((d) => d.category == category).length);
  }

  @override
  ResultFuture<List<DocumentModel>> rescan({void Function(int foundSoFar)? onProgress}) async {
    scanCalls++;
    return failScan
        ? const Left(ServerFailure('Could not scan documents'))
        : Right(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  List<RecentDocumentModel> items = [];
  bool fail = false;
  @override
  ResultFuture<List<RecentDocumentModel>> getRecents() async =>
      fail ? const Left(ServerFailure('Could not load history')) : Right(items);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureAccess implements StorageAccessService {
  final response = Completer<bool>();
  @override
  Future<bool> hasAccess() => response.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ScreenFixture {
  final documents = FixtureDocuments();
  final recents = FixtureRecents();
  final access = FixtureAccess();
  late BaseController controller;
  late Future<void> Function() refresh;
  Future<void> mount(WidgetTester tester, bool home) async {
    Get.put(DocumentInteractionController(
        favoriteRepository: FixtureFavorites(), recentRepository: recents));
    if (home) {
      final c = Get.put(HomeController(
          documentRepository: documents,
          recentRepository: recents,
          storageAccess: access));
      controller = c;
      refresh = c.refresh;
    } else {
      final c = Get.put(FilesController(
          documentRepository: documents, storageAccess: access));
      controller = c;
      refresh = c.refresh;
    }
    await tester.pumpWidget(
        GetMaterialApp(home: home ? const HomeView() : const FilesView()));
  }

  Future<void> complete(WidgetTester tester, {bool allowed = true}) async {
    access.response.complete(allowed);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() {
    Get.reset();
  });

  for (final home in [true, false]) {
    final screen = home ? 'Home' : 'All Files';
    testWidgets('$screen displays loading until access check completes',
        (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, home);
      expect(find.byType(LoadingView), findsOneWidget);
      expect(f.documents.loadCalls, 0);
      await f.complete(tester);
      expect(find.byType(LoadingView), findsNothing);
    });

    testWidgets('$screen displays empty state after an empty successful load',
        (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, home);
      await f.complete(tester);
      expect(f.controller.status.value, StateStatus.empty);
      expect(find.text('No documents found'), findsOneWidget);
    });

    testWidgets('$screen displays indexed documents', (tester) async {
      final f = ScreenFixture();
      f.documents.items = [sample];
      f.recents.items = [
        RecentDocumentModel(
            document: sample,
            lastOpenedAt: DateTime(2026))
      ];
      await f.mount(tester, home);
      await f.complete(tester);
      expect(f.controller.status.value, StateStatus.success);
      // Home now also shows a "Continue Reading" card for the same document
      // above the Recent Documents row (DESIGN_SPEC #08), so its filename
      // can legitimately appear twice.
      expect(find.text('report.pdf'), findsWidgets);
      expect(find.text('No documents found'), findsNothing);
    });

    testWidgets('$screen denies access without querying documents',
        (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, home);
      await f.complete(tester, allowed: false);
      expect(f.documents.loadCalls, 0);
      expect(
          find.text(home
              ? 'OpenReader needs storage access to show your documents.'
              : 'Storage access is required to list files.'),
          findsOneWidget);
    });

    testWidgets('$screen shows a persistent failure and retry restores content',
        (tester) async {
      final f = ScreenFixture();
      f.documents.failLoad = true;
      await f.mount(tester, home);
      await f.complete(tester);
      expect(f.controller.status.value, StateStatus.error);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      f.documents.failLoad = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(f.controller.status.value, StateStatus.empty);
      expect(find.text('No documents found'), findsOneWidget);
      expect(f.controller.errorMessage.value, isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets(
        '$screen retains scan failure instead of replacing it with a load',
        (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, home);
      await f.complete(tester);
      final calls = f.documents.loadCalls;
      f.documents.failScan = true;
      await f.refresh();
      await tester.pumpAndSettle();
      expect(f.controller.status.value, StateStatus.error);
      expect(f.documents.loadCalls, calls);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      f.documents.failScan = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(f.documents.scanCalls, 2);
      expect(f.controller.status.value, StateStatus.empty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('Home surfaces history failure even when category counts succeed',
      (tester) async {
    final f = ScreenFixture();
    f.recents.fail = true;
    await f.mount(tester, true);
    await f.complete(tester);
    expect(f.controller.status.value, StateStatus.error);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Home with indexed files and no recents is not empty',
      (tester) async {
    final f = ScreenFixture();
    f.documents.items = [sample];
    await f.mount(tester, true);
    await f.complete(tester);
    expect(f.controller.status.value, StateStatus.success);
    expect(find.text('No documents found'), findsNothing);
  });

  testWidgets('All Files forwards user search, category and sort choices',
      (tester) async {
    final f = ScreenFixture();
    await f.mount(tester, false);
    await f.complete(tester);
    await tester.enterText(find.byType(TextField), 'report');
    await tester.pumpAndSettle();
    expect(f.documents.query, 'report');
    // The category filter is a custom pill chip (files_view.dart's `_Pill`),
    // not a Material `ChoiceChip`, after the DESIGN_SPEC visual refactor.
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(f.documents.category, DocumentCategory.pdf);
    // Sort is triggered from the visible "current sort" chip
    // (files_view.dart's `_SortChip`) instead of an app-bar icon.
    await tester.tap(find.text(DocumentSortMode.nameAsc.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DocumentSortMode.largestFirst.label));
    await tester.pumpAndSettle();
    expect(f.documents.sort, DocumentSortMode.largestFirst);
  });
}
