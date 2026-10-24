import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/models/recent_document_model.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/widgets/show_dialog/confirm_dialog.dart';
import 'package:openreader/features/favorites/presentation/favorites_controller.dart';
import 'package:openreader/features/favorites/presentation/favorites_view.dart';
import 'package:openreader/features/recents/presentation/recents_controller.dart';
import 'package:openreader/core/presentation/controllers/theme_controller.dart';
import 'package:openreader/features/settings/presentation/settings_controller.dart';
import 'package:openreader/features/settings/presentation/settings_view.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_controller.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_view.dart';
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/features/word_reader/presentation/word_reader_controller.dart';
import 'package:open_reader_kit/docx.dart';
import 'package:open_reader_kit/testing.dart';

/// CR-OPENREADER-UX Phase 2 regressions not covered by document_views_test.

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

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  List<RecentDocumentModel> items = [];
  Map<String, Object?> position = const {};
  int clearCalls = 0;
  @override
  ResultFuture<List<RecentDocumentModel>> getRecents() async => Right(items);
  @override
  ResultFuture<void> clearAll() async {
    clearCalls++;
    items = [];
    return const Right(null);
  }

  @override
  ResultFuture<Map<String, Object?>> getPosition(String documentId) async => Right(position);
  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async =>
      const Right(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureTextSettings implements AppSettingsRepository {
  FixtureTextSettings({this.lineWrap});
  final bool? lineWrap;
  @override
  Future<double?> getTextReaderFontSize() async => null;
  @override
  Future<bool?> getTextReaderLineWrap() async => lineWrap;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FixtureRecents recents;

  setUp(() {
    Get.testMode = true;
    recents = FixtureRecents();
    Get.put(DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: recents));
  });
  tearDown(Get.reset);

  group('Library tab (UX-09/UX-10)', () {
    Future<FavoritesController> mountLibrary(WidgetTester tester) async {
      recents.items = [RecentDocumentModel(document: sample, lastOpenedAt: DateTime(2026))];
      final library = Get.put(FavoritesController(favoriteRepository: FixtureFavorites()));
      Get.put(RecentsController(recentRepository: recents));
      await tester.pumpWidget(const GetMaterialApp(home: FavoritesView()));
      await tester.pumpAndSettle();
      return library;
    }

    testWidgets('is titled Library; Clear History shows only on the History tab', (tester) async {
      await mountLibrary(tester);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('OpenReader'), findsNothing);
      expect(find.byTooltip('Clear History'), findsNothing);

      await tester.tap(find.textContaining('History ('));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear History'), findsOneWidget);
    });

    testWidgets('showHistory (Home "See All") switches to the History tab', (tester) async {
      final library = await mountLibrary(tester);
      library.showHistory();
      await tester.pumpAndSettle();
      expect(library.isHistoryTab.value, isTrue);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.byTooltip('Clear History'), findsOneWidget);
    });

    testWidgets('Clear History asks first; Cancel keeps the history', (tester) async {
      final library = await mountLibrary(tester);
      library.showHistory();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear History'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all reading history?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(recents.clearCalls, 0);

      await tester.tap(find.byTooltip('Clear History'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(recents.clearCalls, 1);
    });
  });

  testWidgets('destructive confirm uses the error colour; dismissing it cancels (UX-15)', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
    final result = showConfirmDialog(title: 'Delete file?', message: 'Gone for good.', confirmLabel: 'Delete', destructive: true);
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Delete'));
    final context = tester.element(find.text('Delete'));
    expect(button.style?.foregroundColor?.resolve({}), Theme.of(context).colorScheme.error);

    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('Settings renders its body, including Clear Recent History (P2r4-qa #1)', (tester) async {
    // The "Storage & Cache" row used to get infinite height inside the
    // ListView, so the whole body failed to lay out and showed blank.
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'OpenReader', packageName: 'p', version: '1', buildNumber: '1', buildSignature: '');
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Get.put(ThemeController());
    Get.put(SettingsController(recentRepository: recents));
    await tester.pumpWidget(const GetMaterialApp(home: SettingsView()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Clear Recent History'), findsOneWidget);
    expect(find.text('Clear Render Cache'), findsOneWidget);
    // No storage scan any more (CR-OPENREADER-BROWSE).
    expect(find.textContaining('Rescan'), findsNothing);
    expect(find.textContaining('indexed'), findsNothing);
    // CR-OPENREADER-COPY: no sandbox / local-only / privacy badges or claims.
    for (final banned in ['SANDBOXED', 'OFFLINE', 'LOCAL', 'Local-only', 'Private', '100% Offline', 'telemetry']) {
      expect(find.textContaining(banned), findsNothing, reason: banned);
    }
    // The app can delete files, so the copy mustn't claim read-only access.
    expect(find.textContaining('only reads'), findsNothing);
  });

  testWidgets('Settings > Clear Recent History asks first (UX-16)', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
    final settings = SettingsController(recentRepository: recents);
    final clearing = settings.clearRecentHistory();
    await tester.pumpAndSettle();
    expect(find.text('Clear all reading history?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await clearing;
    expect(recents.clearCalls, 0);
  });

  group('Text reader jump offsets (UX-21)', () {
    // Measured against the real TextReaderView rows, for both wrap modes.
    for (final wrap in [true, false]) {
      testWidgets('line offsets match the rendered rows (wrap: $wrap)', (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final lines = [
          for (var i = 0; i < 12; i++)
            i.isEven ? 'row $i short' : 'row $i ${List.filled(40 + i * 7, 'wrapword').join(' ')}',
        ];
        final file = await tester.runAsync(() async {
          final dir = await Directory.systemTemp.createTemp('openreader-text-');
          final f = File('${dir.path}/lines.txt');
          await f.writeAsString(lines.join('\n'));
          return f;
        });
        addTearDown(() => file!.parent.deleteSync(recursive: true));
        final document = DocumentModel(
          id: file!.path,
          path: file.path,
          displayName: 'lines.txt',
          extension: 'txt',
          category: DocumentCategory.text,
          sizeBytes: 1,
          modifiedAt: DateTime(2026),
          lastSeenAt: DateTime(2026),
        );
        final controller = Get.put(TextReaderController(
          document: document,
          recentRepository: recents,
          settingsRepository: FixtureTextSettings(lineWrap: wrap),
        ));
        await tester.pumpWidget(const GetMaterialApp(home: TextReaderView()));
        for (var i = 0; i < 50 && controller.status.value.isBusy; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        }
        await tester.pumpAndSettle();
        expect(controller.lineWrap.value, wrap);
        final resolver = controller.lineOffsetResolver;
        expect(resolver, isNotNull);

        final top = tester.getTopLeft(find.text(lines.first)).dy;
        for (var i = 0; i < lines.length; i++) {
          final actual = tester.getTopLeft(find.text(lines[i])).dy - top;
          expect(resolver!(i), moreOrLessEquals(actual, epsilon: 0.5), reason: 'line $i');
        }
      });
    }
  });

  testWidgets('Word reader restores its saved offset (UX-22)', (tester) async {
    recents.position = {'scroll_offset': 1200.0};
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('openreader-word-restore-'));
    addTearDown(() => dir!.delete(recursive: true));
    final file = File('${dir!.path}/long.docx');
    await tester.runAsync(() => file.writeAsBytes(buildDocx([
          for (var i = 0; i < 200; i++) '<w:p><w:r><w:t>Paragraph $i of a long document</w:t></w:r></w:p>',
        ].join())));
    final document = DocumentModel(
      id: file.path,
      path: file.path,
      displayName: 'long.docx',
      extension: 'docx',
      category: DocumentCategory.word,
      sizeBytes: 1,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );
    final controller = WordReaderController(document: document, recentRepository: recents);
    await tester.runAsync(() async {
      controller.onInit();
      for (var i = 0; i < 100 && !controller.word.isLoaded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(controller.initialScrollOffset, 1200.0);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WordDocumentView(controller: controller.word))));
    for (var i = 0; i < 15; i++) {
      await tester.pump();
    }
    expect(controller.scrollController.offset, 1200.0);
  });
}
