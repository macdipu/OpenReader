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
  int queryCalls = 0;
  int scanCalls = 0;

  /// When set, list/count queries wait on it, so a test can observe the
  /// screen mid-reload.
  Completer<void>? hold;

  /// Same, for [rescan].
  Completer<void>? holdScan;
  DocumentCategory? category;
  String? query;
  DocumentSortMode? sort;
  @override
  ResultFuture<List<DocumentModel>> getDocuments(
      {DocumentCategory? category,
      String? query,
      DocumentSortMode sort = DocumentSortMode.nameAsc}) async {
    await hold?.future;
    loadCalls++;
    queryCalls++;
    this.category = category;
    this.query = query;
    this.sort = sort;
    return failLoad
        ? const Left(ServerFailure('Could not load documents'))
        : Right(items);
  }

  @override
  ResultFuture<int> countByCategory(DocumentCategory category) async {
    await hold?.future;
    loadCalls++;
    return failLoad
        ? const Left(ServerFailure('Could not load documents'))
        : Right(items.where((d) => d.category == category).length);
  }

  @override
  ResultFuture<List<DocumentModel>> rescan({void Function(int foundSoFar)? onProgress}) async {
    scanCalls++;
    await holdScan?.future;
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
  bool grantOnRequest = false;
  int requestCalls = 0;
  @override
  Future<bool> hasAccess() async => await response.future || (requestCalls > 0 && grantOnRequest);
  @override
  Future<bool> requestOrOpenSettings() async {
    requestCalls++;
    return grantOnRequest;
  }
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

    testWidgets('$screen keeps content mounted while reloading (UX1-AC1/AC2)',
        (tester) async {
      final f = ScreenFixture();
      f.documents.items = [sample];
      f.recents.items = [RecentDocumentModel(document: sample, lastOpenedAt: DateTime(2026))];
      await f.mount(tester, home);
      await f.complete(tester);
      expect(f.controller.status.value, StateStatus.success);

      f.documents.hold = Completer<void>();
      final reload = home ? (f.controller as HomeController).load() : (f.controller as FilesController).load();
      await tester.pump();
      expect(f.controller.status.value, StateStatus.refreshing);
      expect(find.byType(LoadingView), findsNothing);
      expect(find.text('report.pdf'), findsWidgets);

      f.documents.hold!.complete();
      await reload;
      await tester.pumpAndSettle();
      expect(f.controller.status.value, StateStatus.success);
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

    testWidgets('$screen Retry after a scan failure shows the spinner, not an empty index (review F3)',
        (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, home);
      await f.complete(tester);
      f.documents.failScan = true;
      await f.refresh();
      await tester.pumpAndSettle();
      expect(f.controller.status.value, StateStatus.error);

      f.documents.failScan = false;
      f.documents.holdScan = Completer<void>();
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      expect(f.controller.status.value, StateStatus.loading);
      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.text('No documents found'), findsNothing);

      f.documents.holdScan!.complete();
      await tester.pumpAndSettle();
      expect(f.controller.status.value, StateStatus.empty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('Home shows only the scan banner, not "No documents found", while scanning an empty index (review F3)',
      (tester) async {
    final f = ScreenFixture();
    await f.mount(tester, true);
    await f.complete(tester);
    expect(find.text('No documents found'), findsOneWidget);

    f.documents.holdScan = Completer<void>();
    // Not awaited: the reload after the scan stops at the first-run
    // auto-scan check, whose SharedPreferences call never completes here.
    unawaited(f.refresh());
    await tester.pump();
    expect(f.controller.status.value, StateStatus.refreshing);
    expect((f.controller as HomeController).isScanning.value, isTrue);
    expect(find.byType(LoadingView), findsNothing);
    expect(find.text('No documents found'), findsNothing);

    f.documents.holdScan!.complete();
    await tester.pumpAndSettle();
    expect((f.controller as HomeController).isScanning.value, isFalse);
    expect(find.text('No documents found'), findsOneWidget);
  });

  testWidgets('All Files discards a load superseded by a newer filter (review F6)', (tester) async {
    final f = ScreenFixture();
    f.documents.items = [sample];
    await f.mount(tester, false);
    await f.complete(tester);
    final files = f.controller as FilesController;

    final gate = Completer<void>();
    f.documents.hold = gate;
    final stale = files.load();
    await tester.pump();
    // The newer load (e.g. a filter tap) runs unblocked and finds nothing.
    f.documents.hold = null;
    f.documents.items = [];
    files.selectCategory(DocumentCategory.text);
    await tester.pumpAndSettle();
    expect(files.status.value, StateStatus.empty);

    // The older load finishes last, seeing the fixture's items again.
    f.documents.items = [sample];
    gate.complete();
    await tester.pumpAndSettle();
    expect(files.documents, isEmpty);
    expect(files.status.value, StateStatus.empty);
    await stale;
  });

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

  testWidgets('All Files debounces a typing burst into one query (UX1-AC3)',
      (tester) async {
    final f = ScreenFixture();
    await f.mount(tester, false);
    await f.complete(tester);
    final before = f.documents.queryCalls;
    for (final text in ['r', 're', 'rep', 'repo']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(f.documents.queryCalls, before);
    await tester.pump(FilesController.searchDebounce);
    await tester.pumpAndSettle();
    expect(f.documents.queryCalls, before + 1);
    expect(f.documents.query, 'repo');
  });

  testWidgets('All Files forwards user search, category and sort choices',
      (tester) async {
    final f = ScreenFixture();
    await f.mount(tester, false);
    await f.complete(tester);
    await tester.enterText(find.byType(TextField), 'report');
    await tester.pump(FilesController.searchDebounce);
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

  group('Phase 2 (CR-OPENREADER-UX)', () {
    testWidgets('All Files: tap opens the document, long-press shows the action sheet (UX-08)', (tester) async {
      final f = ScreenFixture();
      f.documents.items = [sample];
      await f.mount(tester, false);
      await f.complete(tester);

      await tester.tap(find.text('report.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Open in Reader'), findsNothing);
      // (The fixture file doesn't exist, so the open itself stops at the
      // missing-file guard; let its snackbar run out.)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('report.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Open in Reader'), findsOneWidget);
    });

    testWidgets('All Files empty index offers Scan storage and pull-to-refresh (UX-17)', (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, false);
      await f.complete(tester);
      expect(find.text('No documents found'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Scan storage'));
      await tester.pumpAndSettle();
      expect(f.documents.scanCalls, 1);
    });

    testWidgets('All Files empty search result says no match, without a scan button (UX-17)', (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, false);
      await f.complete(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(FilesController.searchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('No matching documents'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Scan storage'), findsNothing);
    });

    testWidgets('All Files without access offers Grant Access, then loads (UX-17/18)', (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, false);
      await f.complete(tester, allowed: false);
      expect(find.widgetWithText(FilledButton, 'Grant Access'), findsOneWidget);

      f.access.grantOnRequest = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Grant Access'));
      await tester.pumpAndSettle();
      expect(f.access.requestCalls, 1);
      expect(find.text('No documents found'), findsOneWidget);
    });

    for (final home in [true, false]) {
      final screen = home ? 'Home' : 'All Files';
      testWidgets('$screen keeps a newer load\'s results when a rescan then fails (F6a)', (tester) async {
        final f = ScreenFixture();
        f.documents.items = [sample];
        f.recents.items = [RecentDocumentModel(document: sample, lastOpenedAt: DateTime(2026))];
        await f.mount(tester, home);
        await f.complete(tester);

        f.documents
          ..holdScan = Completer<void>()
          ..failScan = true;
        unawaited(f.refresh());
        await tester.pump();
        // A tab tap / filter change while the scan runs.
        unawaited(home ? (f.controller as HomeController).load() : (f.controller as FilesController).load());
        // Not pumpAndSettle: Home's scan banner spins until the scan ends.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(f.controller.status.value, StateStatus.success);

        f.documents.holdScan!.complete();
        await tester.pumpAndSettle();
        expect(f.controller.status.value, StateStatus.success);
        expect(find.text('report.pdf'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      });

      testWidgets('$screen Retry rescans after a rescan failure, even if an older load landed mid-scan (F6b)',
          (tester) async {
        final f = ScreenFixture();
        f.documents.items = [sample];
        await f.mount(tester, home);
        await f.complete(tester);

        final gate = Completer<void>();
        f.documents.hold = gate;
        unawaited(home ? (f.controller as HomeController).load() : (f.controller as FilesController).load());
        await tester.pump();
        f.documents
          ..holdScan = Completer<void>()
          ..failScan = true;
        unawaited(f.refresh());
        await tester.pump();
        f.documents.hold = null;
        gate.complete(); // the older load finishes during the scan
        await tester.pump();
        f.documents.holdScan!.complete();
        await tester.pumpAndSettle();
        expect(f.controller.status.value, StateStatus.error);

        f.documents
          ..holdScan = null
          ..failScan = false;
        await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
        await tester.pumpAndSettle();
        expect(f.documents.scanCalls, 2);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('Home splits recents: 3 Continue Reading cards, the rest as rows, no duplicates (UX-12)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ScreenFixture();
      final docs = [
        for (var i = 0; i < 5; i++)
          DocumentModel(
            id: '/fixtures/doc$i.txt',
            path: '/fixtures/doc$i.txt',
            displayName: 'doc$i.txt',
            extension: 'txt',
            category: DocumentCategory.text,
            sizeBytes: 1,
            modifiedAt: DateTime(2026),
            lastSeenAt: DateTime(2026),
          ),
      ];
      f.documents.items = docs;
      f.recents.items = [for (final d in docs) RecentDocumentModel(document: d, lastOpenedAt: DateTime(2026))];
      await f.mount(tester, true);
      await f.complete(tester);
      for (final d in docs) {
        expect(find.text(d.displayName), findsOneWidget, reason: d.displayName);
      }
      expect(find.text('Continue Reading'), findsOneWidget);
      expect(find.text('Recent Documents'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'See All'), findsOneWidget);
      // UX-11 / UX-14: no chip reads as selected; the dead tune icon is gone.
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets('Home hides Recent Documents when every recent is a card (UX-12)', (tester) async {
      final f = ScreenFixture();
      f.documents.items = [sample];
      f.recents.items = [RecentDocumentModel(document: sample, lastOpenedAt: DateTime(2026))];
      await f.mount(tester, true);
      await f.complete(tester);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('Recent Documents'), findsNothing);
    });

    testWidgets('Home shows PDF reading progress on its card (UX-13)', (tester) async {
      final f = ScreenFixture();
      f.documents.items = [sample];
      f.recents.items = [
        RecentDocumentModel(
          document: sample,
          lastOpenedAt: DateTime(2026),
          readingPosition: const {'page_number': 5, 'page_count': 20},
        ),
      ];
      await f.mount(tester, true);
      await f.complete(tester);
      expect(
        find.byWidgetPredicate((w) => w is LinearProgressIndicator && w.value == 0.25),
        findsOneWidget,
      );
    });

    testWidgets('Home keeps the scan banner until the last overlapping rescan ends', (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, true);
      await f.complete(tester);
      final home = f.controller as HomeController;

      final first = Completer<void>();
      final second = Completer<void>();
      f.documents.holdScan = first;
      unawaited(home.refresh());
      await tester.pump();
      f.documents.holdScan = second;
      unawaited(home.refresh());
      await tester.pump();

      first.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(home.isScanning.value, isTrue);

      second.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(home.isScanning.value, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('Home reloads when a reader closes (HOME-RECENTS)', (tester) async {
      final f = ScreenFixture();
      await f.mount(tester, true);
      await f.complete(tester);
      final calls = f.documents.loadCalls;
      Get.find<DocumentInteractionController>().readerClosed.value++;
      await tester.pumpAndSettle();
      expect(f.documents.loadCalls, greaterThan(calls));
    });
  });

  testWidgets('Home lays out without overflow at 2x text size (UX-31)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = ScreenFixture();
    f.documents.items = [sample];
    f.recents.items = [
      RecentDocumentModel(
        document: sample,
        lastOpenedAt: DateTime(2026),
        readingPosition: const {'page_number': 2, 'page_count': 4},
      ),
    ];
    await f.mount(tester, true);
    await f.complete(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Continue Reading'), findsOneWidget);
  });
}
