import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/app/shell/app_shell_controller.dart';
import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/models/recent_document_model.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/core/presentation/widgets/loading_view/loading_view.dart';
import 'package:openreader/features/browse/presentation/browse_controller.dart';
import 'package:openreader/features/browse/presentation/browse_view.dart';
import 'package:openreader/features/home/presentation/home_controller.dart';
import 'package:openreader/features/home/presentation/home_view.dart';
import 'package:openreader/services/platform_integration/incoming_intent_service.dart';
import 'package:openreader/services/utilities/folder_browser_service.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';

/// Home and Browse (CR-OPENREADER-BROWSE: no storage scan; documents are
/// found by browsing folders).

DocumentModel doc(String name, {String folder = '/storage/emulated/0/Docs', int size = 100, int modified = 1}) {
  final extension = name.split('.').last;
  return DocumentModel(
    id: '$folder/$name',
    path: '$folder/$name',
    displayName: name,
    extension: extension,
    category: DocumentCategory.fromExtension(extension),
    sizeBytes: size,
    modifiedAt: DateTime.fromMillisecondsSinceEpoch(modified),
    lastSeenAt: DateTime(2026),
  );
}

final sample = doc('report.pdf');

class FixtureRecents implements RecentRepository {
  List<RecentDocumentModel> items = [];
  bool fail = false;
  int loads = 0;

  /// Set (inside a test) to hold a load open and observe the screen mid-load.
  Completer<void>? hold;
  @override
  ResultFuture<List<RecentDocumentModel>> getRecents() async {
    await hold?.future;
    loads++;
    return fail ? const Left(ServerFailure('Could not load history')) : Right(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureFavorites implements FavoriteRepository {
  final toggled = <String>[];
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  ResultFuture<void> toggle(String documentId) async {
    toggled.add(documentId);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureDocuments implements DocumentRepository {
  final indexed = <String>[];
  @override
  ResultFuture<DocumentModel> indexDocument(DocumentModel document) async {
    indexed.add(document.id);
    return Right(document);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureAccess implements StorageAccessService {
  // Lazy: created on first use inside the test body, in the widget test's
  // fake-async zone - one made in setUp completes in the real zone, which
  // tester.pump never flushes.
  late final response = Completer<bool>();
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

class FixtureBrowser implements FolderBrowserService {
  List<BrowseRoot> rootList = const [BrowseRoot(name: 'Internal storage', path: '/storage/emulated/0')];
  final listings = <String, FolderListing>{};
  List<DocumentModel> searchHits = [];
  Completer<void>? holdSearch;

  @override
  Future<List<BrowseRoot>> roots() async => rootList;
  @override
  Future<FolderListing> list(String path) async => listings[path] ?? const FolderListing();
  @override
  Stream<DocumentModel> search(String root, String query) async* {
    await holdSearch?.future;
    for (final d in searchHits) {
      if (d.path.startsWith(root)) yield d;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureIncoming implements IncomingIntentService {
  @override
  Future<void> init() async {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FixtureRecents recents;
  late FixtureFavorites favorites;
  late FixtureDocuments documents;
  late FixtureAccess access;

  setUp(() {
    Get.testMode = true;
    recents = FixtureRecents();
    favorites = FixtureFavorites();
    documents = FixtureDocuments();
    access = FixtureAccess();
    Get.put(DocumentInteractionController(
      favoriteRepository: favorites,
      recentRepository: recents,
      documentRepository: documents,
      storageAccess: access,
    ));
  });
  tearDown(Get.reset);

  group('Home', () {
    Future<HomeController> mountHome(WidgetTester tester, {bool allowed = true}) async {
      final home = Get.put(HomeController(recentRepository: recents, storageAccess: access));
      await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
      return home;
    }

    testWidgets('shows a spinner until the access check completes', (tester) async {
      await mountHome(tester);
      expect(find.byType(LoadingView), findsOneWidget);
      access.response.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(LoadingView), findsNothing);
    });

    testWidgets('with no history: an empty state and a way to Browse - no scan, no counts', (tester) async {
      await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('No reading history yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Browse files'), findsOneWidget);
      expect(find.textContaining('indexed'), findsNothing);
      expect(find.textContaining('scan', findRichText: true), findsNothing);
    });

    testWidgets('Browse files switches to the Browse tab', (tester) async {
      final shell = Get.put(AppShellController(incomingIntentService: FixtureIncoming()));
      await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Browse files'));
      expect(shell.currentIndex.value, AppShellController.filesIndex);
    });

    testWidgets('shows recents and keeps them mounted while reloading', (tester) async {
      recents.items = [RecentDocumentModel(document: sample, lastOpenedAt: DateTime(2026))];
      final home = await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('report.pdf'), findsOneWidget);

      recents.hold = Completer<void>();
      final reload = home.load();
      await tester.pump();
      expect(home.status.value, StateStatus.refreshing);
      expect(find.byType(LoadingView), findsNothing);
      expect(find.text('report.pdf'), findsOneWidget);
      recents.hold!.complete();
      await reload;
    });

    testWidgets('without storage access shows the permission banner', (tester) async {
      await mountHome(tester);
      access.response.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('OpenReader needs storage access to show your documents.'), findsOneWidget);
      expect(recents.loads, 0);
    });

    testWidgets('a history failure offers Retry, which restores the screen', (tester) async {
      recents.fail = true;
      final home = await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      expect(home.status.value, StateStatus.error);
      recents.fail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No reading history yet'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('splits recents: 3 Continue Reading cards, the rest as rows, no duplicates (UX-12)', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final docs = [for (var i = 0; i < 5; i++) doc('doc$i.txt')];
      recents.items = [for (final d in docs) RecentDocumentModel(document: d, lastOpenedAt: DateTime(2026))];
      await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      for (final d in docs) {
        expect(find.text(d.displayName), findsOneWidget, reason: d.displayName);
      }
      expect(find.text('Recent Documents'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets('shows PDF reading progress on its card (UX-13)', (tester) async {
      recents.items = [
        RecentDocumentModel(
          document: sample,
          lastOpenedAt: DateTime(2026),
          readingPosition: const {'page_number': 5, 'page_count': 20},
        ),
      ];
      await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is LinearProgressIndicator && w.value == 0.25), findsOneWidget);
    });

    testWidgets('reloads when a reader closes (HOME-RECENTS)', (tester) async {
      await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      final loads = recents.loads;
      Get.find<DocumentInteractionController>().readerClosed.value++;
      await tester.pumpAndSettle();
      expect(recents.loads, greaterThan(loads));
    });

    testWidgets('lays out without overflow at 2x text size (UX-31)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      recents.items = [RecentDocumentModel(document: sample, lastOpenedAt: DateTime(2026))];
      await mountHome(tester);
      access.response.complete(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Browse', () {
    late FixtureBrowser browser;
    const root = '/storage/emulated/0';

    setUp(() {
      browser = FixtureBrowser();
      browser.listings[root] = FolderListing(
        folders: [Directory('$root/Docs')],
        documents: [doc('top.pdf', folder: root)],
      );
      browser.listings['$root/Docs'] = FolderListing(documents: [
        doc('beta.txt', size: 10, modified: 3),
        doc('Alpha.pdf', size: 30, modified: 1),
        doc('gamma.csv', size: 20, modified: 2),
      ]);
    });

    Future<BrowseController> mountBrowse(WidgetTester tester) async {
      final controller = Get.put(BrowseController(browser: browser, storageAccess: access));
      await tester.pumpWidget(const GetMaterialApp(home: BrowseView()));
      access.response.complete(true);
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('starts at the storage roots, then lists a folder: folders first, then documents', (tester) async {
      final controller = await mountBrowse(tester);
      expect(find.text('Internal storage'), findsOneWidget);
      await tester.tap(find.text('Internal storage'));
      await tester.pumpAndSettle();
      expect(controller.currentPath.value, root);
      expect(find.text('Docs'), findsOneWidget);
      expect(find.text('top.pdf'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Docs')).dy, lessThan(tester.getTopLeft(find.text('top.pdf')).dy));
    });

    testWidgets('folders open, the breadcrumb shows the path, and back goes up', (tester) async {
      final controller = await mountBrowse(tester);
      await controller.openFolder('$root/Docs');
      await tester.pumpAndSettle();
      expect(controller.breadcrumb.map((c) => c.name), ['Internal storage', 'Docs']);
      expect(find.text('Alpha.pdf'), findsOneWidget);

      expect(controller.goUp(), isTrue);
      await tester.pumpAndSettle();
      expect(controller.currentPath.value, root);
      expect(controller.goUp(), isTrue);
      await tester.pumpAndSettle();
      expect(controller.atRoots, isTrue);
      expect(controller.goUp(), isFalse);
    });

    testWidgets('sort, format filter and name filter apply to the folder on screen', (tester) async {
      final controller = await mountBrowse(tester);
      await controller.openFolder('$root/Docs');
      await tester.pumpAndSettle();
      expect(controller.visibleDocuments.map((d) => d.displayName), ['Alpha.pdf', 'beta.txt', 'gamma.csv']);
      controller.setSort(DocumentSortMode.largestFirst);
      expect(controller.visibleDocuments.map((d) => d.displayName), ['Alpha.pdf', 'gamma.csv', 'beta.txt']);
      controller.selectCategory(DocumentCategory.text);
      expect(controller.visibleDocuments.map((d) => d.displayName), ['beta.txt']);
      controller.selectCategory(null);
      await tester.enterText(find.byType(TextField), 'gam');
      await tester.pumpAndSettle();
      expect(find.text('Alpha.pdf'), findsNothing);
      expect(find.text('gamma.csv', findRichText: true), findsOneWidget);
    });

    testWidgets('opening or starring a browsed document indexes it first', (tester) async {
      final controller = await mountBrowse(tester);
      await controller.openFolder('$root/Docs');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha.pdf'));
      await tester.pump();
      expect(documents.indexed, ['$root/Docs/Alpha.pdf']);
      await tester.pump(const Duration(seconds: 4)); // missing-file snackbar
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add to favorites').first);
      await tester.pumpAndSettle();
      expect(documents.indexed.last, '$root/Docs/Alpha.pdf');
      expect(favorites.toggled, ['$root/Docs/Alpha.pdf']);
    });

    testWidgets('search subfolders streams results from the folder on screen', (tester) async {
      browser.searchHits = [doc('Alpha.pdf'), doc('alphabet.txt', folder: '$root/Docs/Sub'), doc('other.pdf', folder: '/elsewhere')];
      final controller = await mountBrowse(tester);
      await controller.openFolder('$root/Docs');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(controller.showingSearch.value, isTrue);
      expect(find.text('2 found for "alpha"'), findsOneWidget);
      expect(find.text('alphabet.txt', findRichText: true), findsOneWidget);

      expect(controller.goUp(), isTrue); // back leaves the results first
      await tester.pumpAndSettle();
      expect(controller.showingSearch.value, isFalse);
      expect(controller.currentPath.value, '$root/Docs');
    });

    testWidgets('a running search can be stopped', (tester) async {
      browser
        ..searchHits = [doc('Alpha.pdf')]
        ..holdSearch = Completer<void>();
      final controller = await mountBrowse(tester);
      unawaited(controller.searchSubfolders('alpha'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Stop'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(controller.isSearching.value, isFalse);
      browser.holdSearch!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a folder the OS refuses says so', (tester) async {
      browser.listings['$root/Android/data'] = const FolderListing(denied: true);
      final controller = await mountBrowse(tester);
      await controller.openFolder('$root/Android/data');
      await tester.pumpAndSettle();
      expect(find.text("This folder can't be opened."), findsOneWidget);
    });

    testWidgets('without access offers Grant Access, then shows the roots', (tester) async {
      Get.put(BrowseController(browser: browser, storageAccess: access));
      await tester.pumpWidget(const GetMaterialApp(home: BrowseView()));
      access.response.complete(false);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Grant Access'), findsOneWidget);
      access.grantOnRequest = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Grant Access'));
      await tester.pumpAndSettle();
      expect(access.requestCalls, 1);
      expect(find.text('Internal storage'), findsOneWidget);
    });

    testWidgets('back only acts on Browse while its tab is showing (review #1)', (tester) async {
      final shell = Get.put(AppShellController(incomingIntentService: FixtureIncoming()));
      final controller = await mountBrowse(tester);
      await controller.openFolder('$root/Docs');
      shell.currentIndex.value = AppShellController.filesIndex;
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope)).canPop, isFalse);
      shell.currentIndex.value = AppShellController.homeIndex;
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope)).canPop, isTrue);
    });

    testWidgets('the search box follows the filter: a folder change clears both (review #3)', (tester) async {
      final controller = await mountBrowse(tester);
      await controller.openFolder('$root/Docs');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gam');
      await tester.pumpAndSettle();
      expect(controller.filter.value, 'gam');
      await controller.openFolder(root);
      await tester.pumpAndSettle();
      expect(controller.filter.value, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    test('nested desktop roots: back and the breadcrumb follow the opened root (review #5)', () async {
      browser.rootList = const [
        BrowseRoot(name: 'Home', path: '/home/u'),
        BrowseRoot(name: 'Documents', path: '/home/u/Documents'),
      ];
      final controller = BrowseController(browser: browser, storageAccess: access);
      access.response.complete(true);
      await controller.load();
      await controller.openRoot(controller.roots.first);
      await controller.openFolder('/home/u/Documents');
      expect(controller.breadcrumb.map((c) => c.name), ['Home', 'Documents']);
      controller.goUp();
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentPath.value, '/home/u');
    });

    test('searching all storage visits nested roots once and caps the whole search (review #2/#5)', () async {
      browser.rootList = const [
        BrowseRoot(name: 'Home', path: '/home/u'),
        BrowseRoot(name: 'Documents', path: '/home/u/Documents'),
      ];
      browser.searchHits = [
        for (var i = 0; i < FolderBrowserService.maxSearchResults + 20; i++) doc('match-$i.txt', folder: '/home/u/Documents'),
      ];
      final controller = BrowseController(browser: browser, storageAccess: access);
      access.response.complete(true);
      await controller.load();
      await controller.searchSubfolders('match');
      expect(controller.searchResults, hasLength(FolderBrowserService.maxSearchResults));
      expect(controller.searchResults.map((d) => d.path).toSet(), hasLength(FolderBrowserService.maxSearchResults));
    });
  });
}
