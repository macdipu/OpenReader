import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/temp_dir.dart';
import 'package:openreader/core/presentation/widgets/reader/reader_preview_strip.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/models/recent_document_model.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/features/powerpoint_reader/presentation/powerpoint_reader_controller.dart';
import 'package:openreader/features/powerpoint_reader/presentation/powerpoint_reader_view.dart';
import 'package:universal_document_viewer/slides.dart';
import 'package:path/path.dart' as p;

import 'package:universal_document_viewer/testing.dart';

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  ResultFuture<void> toggle(String documentId) async => const Right(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  Map<String, Object?> position = const {};
  int markOpenedCalls = 0;
  Map<String, Object?>? lastReadingPosition;

  @override
  ResultFuture<Map<String, Object?>> getPosition(String documentId) async => Right(position);

  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async {
    markOpenedCalls++;
    lastReadingPosition = readingPosition;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late FixtureRecents recents;
  late DocumentInteractionController interactions;

  DocumentModel documentAt(String path) => DocumentModel(
        id: path,
        path: path,
        displayName: p.basename(path),
        extension: 'pptx',
        category: DocumentCategory.powerpoint,
        sizeBytes: 1,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );

  Future<DocumentModel> deck(List<String> slides) async {
    final file = File(p.join(root.path, 'deck.pptx'));
    await file.writeAsBytes(buildPptx(slides));
    return documentAt(file.path);
  }

  // Parses inline: the isolate hop is the only difference from production.
  PowerPointReaderController controllerFor(DocumentModel document) => PowerPointReaderController(
        document: document,
        recentRepository: recents,
        interactions: interactions,
        parse: (bytes) async => PptxParser.parse(bytes),
      );

  Future<PowerPointReaderController> loaded(PowerPointReaderController c) async {
    c.onInit();
    for (var i = 0; i < 100 && c.status.value.isBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return c;
  }

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-pptx-reader-');
    recents = FixtureRecents();
    interactions = DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: recents);
  });

  tearDown(() async {
    Get.reset();
    await deleteTempDir(root);
  });

  final threeSlides = [
    titleShape('Welcome') + bodyShape([('Hello there', 0)]),
    titleShape('Budget') + bodyShape([('Revenue grew', 0)]),
    titleShape('Revenue outlook'),
  ];

  group('loading', () {
    test('parses the slides and starts on the first one', () async {
      final c = await loaded(controllerFor(await deck(threeSlides)));
      expect(c.status.value, StateStatus.success);
      expect(c.slides.map((s) => s.title), ['Welcome', 'Budget', 'Revenue outlook']);
      expect(c.currentSlide, 0);
    });

    test('restores the saved slide, clamped to the slides that still exist', () async {
      recents.position = {'slide_index': 9, 'slide_count': 10};
      final c = await loaded(controllerFor(await deck(threeSlides)));
      expect(c.currentSlide, 2);
    });

    test('a file that is not a PowerPoint package shows the damaged-file message', () async {
      final file = File(p.join(root.path, 'broken.pptx'));
      await file.writeAsBytes([1, 2, 3, 4]);
      final c = await loaded(controllerFor(documentAt(file.path)));
      expect(c.hasError.value, isTrue);
      expect(c.errorMessage.value, 'This document may be damaged or incomplete.');
    });

    test('a presentation without slides is empty, not an error', () async {
      final c = await loaded(controllerFor(await deck([])));
      expect(c.hasError.value, isFalse);
      expect(c.status.value, StateStatus.empty);
    });
  });

  group('reading position', () {
    test('a slide change is saved after a 2 second debounce, with the slide count', () async {
      final c = await loaded(controllerFor(await deck(threeSlides)));
      fakeAsync((async) {
        c.deck.goToSlide(1);
        async.elapse(const Duration(seconds: 1));
        expect(recents.markOpenedCalls, 0);
        async.elapse(const Duration(seconds: 1));
        expect(recents.lastReadingPosition, {'slide_index': 1, 'slide_count': 3});
      });
    });

    test('closing saves the slide once more, only if the reader moved', () async {
      final untouched = await loaded(controllerFor(await deck(threeSlides)));
      untouched.onClose();
      expect(recents.markOpenedCalls, 0);

      final moved = await loaded(controllerFor(await deck(threeSlides)));
      moved.deck.goToSlide(2);
      moved.onClose();
      expect(recents.lastReadingPosition, {'slide_index': 2, 'slide_count': 3});
    });

    test('History shows slide progress', () {
      final recent = RecentDocumentModel(
        document: documentAt('/deck.pptx'),
        lastOpenedAt: DateTime(2026),
        readingPosition: const {'slide_index': 4, 'slide_count': 10},
      );
      expect(recent.progress, 0.5);
    });
  });

  group('search', () {
    test('finds matching slides, starting from the slide on screen, and cycles through them', () async {
      final c = await loaded(controllerFor(await deck(threeSlides)));
      c.onSearchQueryChanged('revenue');
      expect(c.matches, const [SlideMatch(1, 0), SlideMatch(2, 0)]);
      expect(c.currentSlide, 1);
      c.goToNextMatch();
      expect(c.currentSlide, 2);
      c.goToNextMatch();
      expect(c.currentSlide, 1);
      c.goToPrevMatch();
      expect(c.currentSlide, 2);
    });

    test('no match leaves the slide alone; closing search clears it', () async {
      final c = await loaded(controllerFor(await deck(threeSlides)));
      c.onSearchQueryChanged('nowhere');
      expect(c.matches, isEmpty);
      expect(c.currentSlide, 0);
      c.stopSearching();
      expect(c.searchQuery, '');
    });
  });

  group('view', () {
    Future<PowerPointReaderController> pumpReader(WidgetTester tester, List<String> slides) async {
      final document = await tester.runAsync(() => deck(slides));
      final c = controllerFor(document!);
      // Get.put runs onInit, which starts the load. It must start inside
      // runAsync: file I/O started in the test's fake-async zone resumes on
      // its microtask queue, which only drains on pump, so the load would
      // stay busy and LoadingView's spinner would never settle.
      await tester.runAsync(() async {
        Get.put(c);
        for (var i = 0; i < 100 && c.status.value.isBusy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpWidget(const GetMaterialApp(home: PowerPointReaderView()));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('shows one slide with a counter, and the arrows and keyboard move between slides', (tester) async {
      final c = await pumpReader(tester, threeSlides);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Slide 1 of 3'), findsOneWidget);
      expect(find.byTooltip('Previous slide'), findsOneWidget);

      await tester.tap(find.byTooltip('Next slide'));
      await tester.pumpAndSettle();
      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('Slide 2 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(c.currentSlide, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(c.currentSlide, 1);
      c.onClose();
    });

    testWidgets('the previews show the slides around the current one; tapping one goes there', (tester) async {
      final c = await pumpReader(tester, threeSlides);
      expect(find.byType(ReaderPreviewStrip), findsNothing);
      await tester.tap(find.byTooltip('Slide thumbnails'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPreviewStrip), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(ReaderPreviewStrip), matching: find.text('3')));
      await tester.pumpAndSettle();
      expect(c.currentSlide, 2);
      expect(find.text('Slide 3 of 3'), findsOneWidget);
      c.onClose();
    });

    testWidgets('search reports no matches', (tester) async {
      final c = await pumpReader(tester, threeSlides);
      await tester.tap(find.byTooltip('Search in slides'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zebra');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      c.onClose();
    });
  });
}
