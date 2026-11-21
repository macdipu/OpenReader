import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/home/presentation/widgets/recent_files_table.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/models/recent_document_model.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/controllers/thumbnail_preferences.dart';
import 'package:openreader/features/home/presentation/home_controller.dart';
import 'package:openreader/features/home/presentation/home_formatters.dart';
import 'package:openreader/features/home/presentation/home_view.dart';
import 'package:openreader/features/home/presentation/widgets/continue_reading_row.dart';
import 'package:openreader/features/home/presentation/widgets/middle_ellipsis_text.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';

/// Desktop Home: the split-panel workspace (toolbar, Continue reading, Recent files table,
/// inspector) on macOS, Windows and Linux.

const _folder = '/Users/someone/Library/Application Support/OpenReader/scratchpad/projects/2026/samples';

DocumentModel _doc(String name, {int size = 1000, String folder = _folder}) {
  final extension = name.split('.').last;
  return DocumentModel(
    id: '$folder/$name',
    path: '$folder/$name',
    displayName: name,
    extension: extension,
    category: DocumentCategory.fromExtension(extension),
    sizeBytes: size,
    modifiedAt: DateTime(2026, 11, 2),
    lastSeenAt: DateTime(2026),
  );
}

class _Recents implements RecentRepository {
  List<RecentDocumentModel> items = [];
  bool fail = false;
  Completer<void>? hold;
  final removed = <String>[];

  @override
  ResultFuture<List<RecentDocumentModel>> getRecents() async {
    await hold?.future;
    return fail ? const Left(ServerFailure('Could not load history')) : Right(List.of(items));
  }

  @override
  ResultFuture<void> remove(String documentId) async {
    removed.add(documentId);
    items.removeWhere((r) => r.document.id == documentId);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Favorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  ResultFuture<void> toggle(String documentId) async => const Right(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Documents implements DocumentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Access implements StorageAccessService {
  bool granted = true;
  @override
  Future<bool> hasAccess() async => granted;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records opens instead of pushing readers.
class _Interactions extends DocumentInteractionController {
  final opened = <String>[];
  final openedBeside = <String>[];

  _Interactions(_Recents recents, _Access access)
      : super(
          favoriteRepository: _Favorites(),
          recentRepository: recents,
          documentRepository: _Documents(),
          storageAccess: access,
        );

  @override
  Future<void> openDocument(DocumentModel document, {bool fromOtherApp = false}) async => opened.add(document.id);

  @override
  Future<void> openBeside(DocumentModel document) async => openedBeside.add(document.id);
}

/// Sidebar width the shell gives the extended sidebar plus its divider.
const _sidebar = 253.0;

void main() {
  late _Recents recents;
  late _Access access;
  late _Interactions interactions;

  final docs = [
    _doc('orders.xlsx', size: 5939),
    _doc('budget.xlsm', size: 2458),
    _doc('annual report with a very long name that will not fit.pdf', size: 900000),
    _doc('notes.txt', size: 120),
    _doc('deck.pptx', size: 70000),
    _doc('contract.docx', size: 30000),
  ];
  final now = DateTime.now();
  List<RecentDocumentModel> history() => [
        RecentDocumentModel(
          document: docs[0],
          lastOpenedAt: now.subtract(const Duration(minutes: 5)),
          readingPosition: const {'sheet_index': 1},
        ),
        RecentDocumentModel(
          document: docs[1],
          lastOpenedAt: now.subtract(const Duration(hours: 3)),
          readingPosition: const {'sheet_index': 0},
        ),
        RecentDocumentModel(
          document: docs[2],
          lastOpenedAt: now.subtract(const Duration(days: 2)),
          readingPosition: const {'page_number': 12, 'page_count': 40},
        ),
        RecentDocumentModel(
          document: docs[3],
          lastOpenedAt: now.subtract(const Duration(days: 3)),
          readingPosition: const {'line': 9},
        ),
        RecentDocumentModel(
          document: docs[4],
          lastOpenedAt: now.subtract(const Duration(days: 4)),
          readingPosition: const {'slide_index': 2, 'slide_count': 10},
        ),
        RecentDocumentModel(document: docs[5], lastOpenedAt: now.subtract(const Duration(days: 5))),
      ];

  tearDown(() => RecentFilesTable.debugNow = null);

  setUp(() {
    // Double-click timing on the fake test clock, not wall time (a busy full run spaced the
    // two taps of a double click further apart than the double-tap timeout).
    RecentFilesTable.debugNow = () => TestWidgetsFlutterBinding.instance.clock.now();
    Get.testMode = true;
    // Format icons, not rendered previews: no thumbnail work in widget tests.
    ThumbnailPreferences.hidden.value = true;
    recents = _Recents()..items = history();
    access = _Access();
    interactions = _Interactions(recents, access);
    Get.put<DocumentInteractionController>(interactions);
  });
  tearDown(() {
    ThumbnailPreferences.hidden.value = false;
    Get.reset();
  });

  Future<HomeController> mount(WidgetTester tester, {double width = 1366, double height = 900, bool settle = true}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Created when Home first builds, as in the shell, so a load failure's snackbar has an overlay.
    Get.lazyPut(() => HomeController(recentRepository: recents, storageAccess: access));
    // The shell's sidebar beside Home, as on desktop.
    await tester.pumpWidget(const GetMaterialApp(
      home: Row(children: [SizedBox(width: _sidebar), Expanded(child: HomeView())]),
    ));
    if (settle) await tester.pumpAndSettle();
    return Get.find<HomeController>();
  }

  Finder row(String name) => find.byKey(ValueKey('home-row-$_folder/$name'));
  Finder inspector() => find.byKey(const ValueKey('home-inspector'));
  Finder inInspector(Finder f) => find.descendant(of: inspector(), matching: f);
  double inspectorWidth(WidgetTester tester) => tester.getSize(inspector()).width;

  Future<void> pressShortcut(WidgetTester tester, LogicalKeyboardKey key) async {
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  group('layout', () {
    for (final width in [1100.0, 1366.0, 1920.0]) {
      testWidgets('at $width px: no overflow, one title, one search, no Browse files, cards inside the pane',
          (tester) async {
        await mount(tester, width: width);
        expect(tester.takeException(), isNull);

        expect(find.byKey(const ValueKey('home-desktop')), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('OpenReader'), findsNothing);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(find.text('Search documents'), findsOneWidget);
        expect(find.text(defaultTargetPlatform == TargetPlatform.macOS ? '⌘F' : 'Ctrl+F'), findsOneWidget);
        expect(find.textContaining('Browse files'), findsNothing);

        final pane = tester.getRect(find.byKey(const ValueKey('home-main-scroll')));
        final cards = find.byType(ContinueReadingCard);
        final count = tester.widgetList(cards).length;
        expect(count, ContinueReadingRow.columnsFor(pane.width - 48).clamp(1, 4));
        for (var i = 0; i < count; i++) {
          final card = tester.getRect(cards.at(i));
          expect(card.left, greaterThanOrEqualTo(pane.left), reason: 'card $i left');
          expect(card.right, lessThanOrEqualTo(pane.right - 24 + 0.01), reason: 'card $i clipped at $width');
        }

        // Docked from 1280 px; a drawer below.
        final docked = width >= 1280;
        expect(find.byKey(const ValueKey('home-inspector-docked')), docked ? findsOneWidget : findsNothing);
        if (docked) {
          expect(inspectorWidth(tester), HomeController.inspectorDefaultWidth);
          expect(pane.right, lessThanOrEqualTo(width - HomeController.inspectorDefaultWidth));
        } else {
          expect(pane.width, width - _sidebar);
        }
      }, variant: TargetPlatformVariant.desktop());
    }

    testWidgets('lays out without overflow at 2x text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, width: 1366);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('continue reading', () {
    testWidgets('shows format, size, position and relative time; a click opens', (tester) async {
      await mount(tester, width: 1920);
      final card = find.byKey(ValueKey('continue-card-$_folder/${docs[2].displayName}'));
      expect(find.descendant(of: card, matching: find.text(formatAndSize(history()[2]))), findsOneWidget);
      expect(formatAndSize(history()[0]), 'Excel · 5.8 KB');
      expect(find.descendant(of: card, matching: find.text('Page 12 of 40 · 2 days ago')), findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(interactions.opened, [docs[2].id]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('is hidden when nothing has a reading position', (tester) async {
      recents.items = [for (final r in history()) RecentDocumentModel(document: r.document, lastOpenedAt: r.lastOpenedAt)];
      await mount(tester);
      expect(find.text('Continue reading'), findsNothing);
      expect(find.byType(ContinueReadingCard), findsNothing);
      expect(find.text('Recent files'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('recent files table', () {
    double top(WidgetTester tester, String name) => tester.getTopLeft(row(name)).dy;

    testWidgets('has the columns, folder names not paths, and sorts by a header click', (tester) async {
      await mount(tester, width: 1920);
      for (final title in ['Name', 'Type', 'Size', 'Last opened']) {
        expect(find.byKey(ValueKey('home-sort-$title')), findsOneWidget, reason: title);
      }
      expect(find.descendant(of: row('orders.xlsx'), matching: find.text('samples')), findsOneWidget);
      expect(find.textContaining(_folder), findsNothing);
      expect(find.byKey(const ValueKey('home-sort-indicator-Last opened')), findsOneWidget);
      expect(top(tester, 'orders.xlsx'), lessThan(top(tester, 'contract.docx')));

      await tester.tap(find.byKey(const ValueKey('home-sort-Name')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-sort-indicator-Name')), findsOneWidget);
      Icon indicator(String column) => tester.widget<Icon>(find.byKey(ValueKey('home-sort-indicator-$column')));
      expect(indicator('Name').icon, Icons.arrow_upward_rounded);
      expect(top(tester, 'annual report with a very long name that will not fit.pdf'), lessThan(top(tester, 'budget.xlsm')));
      expect(top(tester, 'budget.xlsm'), lessThan(top(tester, 'orders.xlsx')));

      await tester.tap(find.byKey(const ValueKey('home-sort-Name')));
      await tester.pumpAndSettle();
      expect(indicator('Name').icon, Icons.arrow_downward_rounded);
      expect(top(tester, 'orders.xlsx'), lessThan(top(tester, 'budget.xlsm')));

      await tester.tap(find.byKey(const ValueKey('home-sort-Size')));
      await tester.pumpAndSettle();
      // Largest first.
      expect(top(tester, 'annual report with a very long name that will not fit.pdf'), lessThan(top(tester, 'notes.txt')));
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('a click selects into the inspector; Up / Down move it; Enter and double click open', (tester) async {
      await mount(tester, width: 1366);
      expect(find.text('Select a file to see its details'), findsOneWidget);

      await tester.tap(row('budget.xlsm'));
      await tester.pumpAndSettle();
      expect(inInspector(find.text('budget.xlsm')), findsOneWidget);
      expect(interactions.opened, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(inInspector(find.text('annual report with a very long name that will not fit.pdf')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(inInspector(find.text('orders.xlsx')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(interactions.opened, [docs[0].id]);

      await tester.tap(row('notes.txt'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(row('notes.txt'));
      await tester.pumpAndSettle();
      expect(interactions.opened, [docs[0].id, docs[3].id]);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets('Delete asks, then removes the selected row from history', (tester) async {
      final home = await mount(tester);
      await tester.tap(row('notes.txt'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.text('Remove from history?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(recents.removed, [docs[3].id]);
      expect(row('notes.txt'), findsNothing);
      // The next row takes the selection.
      expect(home.selectedId.value, docs[4].id);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('right-click shows the actions menu', (tester) async {
      await mount(tester);
      await tester.tap(row('orders.xlsx'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      for (final label in ['Open', 'Open beside', 'Share', 'Copy path', 'Remove from history', 'Delete file']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await tester.tap(find.text('Open beside').last);
      await tester.pumpAndSettle();
      expect(interactions.openedBeside, [docs[0].id]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('long history: See all leads to Library', (tester) async {
      recents.items = [
        for (var i = 0; i < HomeController.tableRowLimit + 5; i++)
          RecentDocumentModel(document: _doc('file$i.txt'), lastOpenedAt: now.subtract(Duration(hours: i))),
      ];
      final home = await mount(tester);
      expect(home.tableRows, hasLength(HomeController.tableRowLimit));
      expect(find.widgetWithText(TextButton, 'See all'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('inspector', () {
    testWidgets('one Open, Open beside, labeled actions and details with a middle-truncated location',
        (tester) async {
      await mount(tester);
      await tester.tap(row('orders.xlsx'));
      await tester.pumpAndSettle();

      expect(inInspector(find.widgetWithText(FilledButton, 'Open')), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget, reason: 'one primary action on the screen');
      expect(inInspector(find.widgetWithText(OutlinedButton, 'Open beside')), findsOneWidget);
      expect(inInspector(find.text('Excel · 5.8 KB')), findsOneWidget);
      for (final label in [
        'Add to favorites',
        'Share',
        'Open with another app',
        'Show in folder',
        'Copy path',
        'File info',
        'Remove from history',
      ]) {
        expect(inInspector(find.text(label)), findsOneWidget, reason: label);
      }
      for (final label in ['Last opened', 'Modified', 'Size', 'Location']) {
        expect(inInspector(find.text(label)), findsOneWidget, reason: label);
      }

      final location = find.byKey(const ValueKey('home-inspector-location'));
      expect(tester.widget<Tooltip>(location).message, _folder);
      final shown = tester.widget<Text>(find.descendant(of: location, matching: find.byType(Text))).data!;
      expect(shown, contains('…'));
      final [head, tail] = shown.split('…');
      expect(head, isNotEmpty);
      expect(tail, isNotEmpty);
      expect(_folder, startsWith(head));
      expect(_folder, endsWith(tail));
      expect(shown.length, lessThan(_folder.length));
      expect(tester.takeException(), isNull);

      await tester.tap(inInspector(find.text('Open beside')));
      await tester.pumpAndSettle();
      expect(interactions.openedBeside, [docs[0].id]);
      await tester.tap(inInspector(find.text('Open')));
      await tester.pumpAndSettle();
      expect(interactions.opened, [docs[0].id]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('resizes between 280 and 420 by drag and keys, double-click resets', (tester) async {
      final home = await mount(tester, width: 1600);
      final handle = find.byKey(const ValueKey('home-inspector-resize'));
      expect(inspectorWidth(tester), 320);

      await tester.drag(handle, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(inspectorWidth(tester), HomeController.inspectorMaxWidth);

      await tester.drag(handle, const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(inspectorWidth(tester), HomeController.inspectorMinWidth);

      Focus.of(tester.element(handle)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(inspectorWidth(tester), HomeController.inspectorMinWidth + 16);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(inspectorWidth(tester), HomeController.inspectorMinWidth);

      await tester.tap(handle);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(home.inspectorWidth.value, HomeController.inspectorDefaultWidth);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets('Cmd/Ctrl+I and the toolbar button hide and show it', (tester) async {
      await mount(tester);
      expect(find.byKey(const ValueKey('home-inspector-docked')), findsOneWidget);
      await pressShortcut(tester, LogicalKeyboardKey.keyI);
      expect(find.byKey(const ValueKey('home-inspector-docked')), findsNothing);
      expect(inspector(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-inspector-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-inspector-docked')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets('below 1280 px it is a closable overlay drawer', (tester) async {
      await mount(tester, width: 1100);
      expect(inspector(), findsNothing);
      await tester.tap(row('orders.xlsx'));
      await tester.pumpAndSettle();
      final drawer = find.byKey(const ValueKey('home-inspector-overlay'));
      expect(drawer, findsOneWidget);
      expect(find.byKey(const ValueKey('home-inspector-docked')), findsNothing);
      // Over the main pane, which keeps its full width.
      expect(tester.getSize(find.byKey(const ValueKey('home-main-scroll'))).width, 1100 - _sidebar);
      expect(tester.getRect(inspector()).right, 1100);
      expect(inInspector(find.text('orders.xlsx')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(drawer, findsNothing);

      await pressShortcut(tester, LogicalKeyboardKey.keyI);
      expect(drawer, findsOneWidget);
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      expect(drawer, findsNothing);
    }, variant: TargetPlatformVariant.desktop());
  });

  group('states', () {
    testWidgets('no history: next actions, no table, no inspector', (tester) async {
      recents.items = [];
      final home = await mount(tester);
      expect(find.text('No recent files yet'), findsOneWidget);
      expect(find.text('Open a file'), findsOneWidget);
      expect(find.text('Browse your folders'), findsOneWidget);
      expect(find.text(defaultTargetPlatform == TargetPlatform.macOS ? '⌘O' : 'Ctrl+O'), findsOneWidget);
      expect(find.text('Recent files'), findsNothing);
      expect(inspector(), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('home-inspector-toggle'))).onPressed, isNull);
      expect(home.status.value.name, 'empty');
    }, variant: TargetPlatformVariant.desktop());

    testWidgets('loading shows skeleton rows', (tester) async {
      recents.hold = Completer<void>();
      await mount(tester, settle: false);
      await tester.pump();
      expect(find.byKey(const ValueKey('home-skeleton')), findsOneWidget);
      recents.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-skeleton')), findsNothing);
      expect(row('orders.xlsx'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('an error shows the message and Retry restores the list', (tester) async {
      recents.fail = true;
      await mount(tester);
      expect(find.text('Could not load history'), findsWidgets);
      recents.fail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(row('orders.xlsx'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('without storage access the banner code path still shows', (tester) async {
      access.granted = false;
      await mount(tester);
      expect(find.text('OpenReader needs storage access to show your documents.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('phones keep the feed', () {
    testWidgets('Android at phone width is not the workspace', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Get.put(HomeController(recentRepository: recents, storageAccess: access));
      await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-desktop')), findsNothing);
      expect(find.text('OpenReader'), findsOneWidget);
      expect(find.text('Browse files'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('formatters', () {
    test('relative time, reading position and middle truncation', () {
      final at = DateTime(2026, 11, 21, 12);
      expect(formatRelativeTimeLong(at.subtract(const Duration(days: 2)), now: at), '2 days ago');
      expect(formatRelativeTimeLong(at.subtract(const Duration(days: 1)), now: at), 'Yesterday');
      expect(formatRelativeTimeLong(at.subtract(const Duration(minutes: 1)), now: at), '1 minute ago');
      RecentDocumentModel withPosition(Map<String, Object?> position) =>
          RecentDocumentModel(document: _doc('a.pdf'), lastOpenedAt: at, readingPosition: position);
      expect(readingPositionLabel(withPosition(const {'page_number': 12, 'page_count': 40})), 'Page 12 of 40');
      expect(readingPositionLabel(withPosition(const {'sheet_index': 1})), 'Sheet 2');
      expect(readingPositionLabel(withPosition(const {'slide_index': 0})), 'Slide 1');
      expect(readingPositionLabel(withPosition(const {'scroll_offset': 10.0})), isNull);
      final cut = middleTruncate('abcdefghijklmnopqrstuvwxyz', 10, (s) => s.length.toDouble());
      expect(cut, 'abcde…wxyz');
      expect(middleTruncate('short', 10, (s) => s.length.toDouble()), 'short');
    });
  });
}
