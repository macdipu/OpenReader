import 'dart:async';
import 'dart:io';

import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:universal_document_viewer/pdf.dart';
import 'package:openreader/features/pdf_reader/presentation/pdf_reader_controller.dart';
import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/temp_dir.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

// These tests don't open a document (universal_document_viewer's own tests cover the
// PDF engine against real PDFium). They cover the logic around it:
// initial-position restore, debounced position saving, and delegation to
// DocumentInteractionController.

class FixtureFavorites implements FavoriteRepository {
  final _favorites = <String>{};

  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);

  @override
  ResultFuture<void> toggle(String documentId) async {
    if (!_favorites.remove(documentId)) _favorites.add(documentId);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  Map<String, Object?> position = const {};
  int markOpenedCalls = 0;
  String? lastMarkedId;
  Map<String, Object?>? lastReadingPosition;

  /// When set, saves wait on it, so a test can observe a save in flight.
  Completer<void>? holdSave;

  @override
  ResultFuture<Map<String, Object?>> getPosition(String documentId) async => Right(position);

  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async {
    await holdSave?.future;
    markOpenedCalls++;
    lastMarkedId = documentId;
    lastReadingPosition = readingPosition;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureSettings implements AppSettingsRepository {
  bool continuous = true;
  bool? nightMode;

  @override
  Future<bool?> getReaderNightMode() async => nightMode;

  @override
  Future<void> setReaderNightMode(bool value) async => nightMode = value;

  @override
  Future<bool> getDefaultContinuousScroll() async => continuous;

  @override
  Future<void> setDefaultContinuousScroll(bool value) async => continuous = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DocumentModel document;
  late DocumentModel missingDocument;
  late FixtureRecents recents;
  late DocumentInteractionController interactions;
  late PdfReaderController controller;
  late FixtureSettings settings;

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('openreader-pdf-reader-');
    final file = File(p.join(root.path, 'report.pdf'));
    await file.writeAsString('fixture');
    document = DocumentModel(
      id: file.path,
      path: file.path,
      displayName: 'report.pdf',
      extension: 'pdf',
      category: DocumentCategory.pdf,
      sizeBytes: 10,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );
    missingDocument = DocumentModel(
      id: p.join(root.path, 'missing.pdf'),
      path: p.join(root.path, 'missing.pdf'),
      displayName: 'missing.pdf',
      extension: 'pdf',
      category: DocumentCategory.pdf,
      sizeBytes: 10,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

    recents = FixtureRecents();
    interactions = DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: recents);
    settings = FixtureSettings();
    controller = PdfReaderController(document: document, recentRepository: recents, interactions: interactions, settingsRepository: settings);
  });

  tearDown(() async {
    Get.reset();
    await deleteTempDir(root);
  });

  group('initial position restore', () {
    test('onInit restores the persisted page number', () async {
      recents.position = {'page_number': 7};
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(controller.initialPageNumber, 7);
      expect(controller.status.value, StateStatus.success);
    });

    test('defaults to page 1 when no position is stored', () async {
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(controller.initialPageNumber, 1);
    });

    test('ignores a non-positive or malformed page_number', () async {
      recents.position = {'page_number': 0};
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(controller.initialPageNumber, 1);
    });
  });

  group('reading position persistence', () {
    test('onPageChanged saves after a 2 second debounce', () {
      fakeAsync((async) {
        controller.pdf.onPageChanged(5); // ignore: invalid_use_of_internal_member
        expect(controller.currentPage.value, 5);
        expect(recents.markOpenedCalls, 0);

        async.elapse(const Duration(seconds: 1));
        expect(recents.markOpenedCalls, 0);

        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        expect(recents.markOpenedCalls, 1);
        expect(recents.lastMarkedId, document.id);
        expect(recents.lastReadingPosition, {'page_number': 5, 'view_mode': 'continuous'});
      });
    });

    test('a new page change resets the debounce and only the latest page is saved', () {
      fakeAsync((async) {
        controller.pdf.onPageChanged(2); // ignore: invalid_use_of_internal_member
        async.elapse(const Duration(seconds: 1));
        controller.pdf.onPageChanged(3); // ignore: invalid_use_of_internal_member
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        expect(recents.markOpenedCalls, 0);

        async.elapse(const Duration(seconds: 1));
        expect(recents.markOpenedCalls, 1);
        expect(recents.lastReadingPosition, {'page_number': 3, 'view_mode': 'continuous'});
      });
    });


    test('onClose is a no-op when the viewer was never attached', () {
      expect(controller.pageCount.value, 0);
      expect(controller.isReady.value, isFalse);
      expect(controller.onClose, returnsNormally);
      expect(recents.markOpenedCalls, 0);
    });

    test('onClose persists the current page once the document is ready', () async {
      controller.pdf.debugSetPages(pageCount: 3, currentPage: 3);
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.markOpenedCalls, 1);
      expect(recents.lastReadingPosition, {'page_number': 3, 'page_count': 3, 'view_mode': 'continuous'});
    });
  });

  group('history refresh on close (HOME-RECENTS)', () {
    test('readerClosed fires only after the final position save has landed', () async {
      controller.pdf.debugSetPages(pageCount: 8, currentPage: 6);
      recents.holdSave = Completer<void>();
      final before = interactions.readerClosed.value;
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(interactions.readerClosed.value, before, reason: 'save still in flight');

      recents.holdSave!.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(recents.lastReadingPosition?['page_number'], 6);
      expect(interactions.readerClosed.value, before + 1);
    });

    test('readerClosed fires at once when there is nothing to save', () {
      final before = interactions.readerClosed.value;
      controller.onClose();
      expect(interactions.readerClosed.value, before + 1);
    });
  });

  group('night mode and fullscreen (UX-33)', () {
    test('night mode starts from the saved preference and is saved when toggled', () async {
      settings.nightMode = true;
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.nightMode.value, isTrue);
      controller.toggleNightMode();
      expect(controller.nightMode.value, isFalse);
      expect(settings.nightMode, isFalse);
    });

    test('fullscreen hides the thumbnails and is left on close', () {
      controller.showThumbnails.value = true;
      controller.toggleFullscreen();
      expect(controller.isFullscreen.value, isTrue);
      expect(controller.showThumbnails.value, isFalse);
      controller.onClose();
      expect(controller.isFullscreen.value, isFalse);
    });

    test('Esc leaves fullscreen first, then search; Ctrl+F leaves fullscreen to search (P3-review)', () {
      controller.toggleFullscreen();
      controller.escape();
      expect(controller.isFullscreen.value, isFalse);

      controller.toggleFullscreen();
      controller.searchFromShortcut();
      expect(controller.isFullscreen.value, isFalse);
      expect(controller.isSearching.value, isTrue);
      controller.escape();
      expect(controller.isSearching.value, isFalse);
    });

    test('zoom and fit are safe before the viewer is ready', () {
      controller.zoomIn();
      controller.zoomOut();
      controller.fitWidth();
    });
  });

  group('per-document view mode (UX-19)', () {
    test('a PDF\'s remembered mode wins over the Settings default', () async {
      recents.position = {'page_number': 2, 'view_mode': 'horizontal'};
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.viewMode.value, PdfViewMode.horizontal);
    });

    test('a PDF with no remembered mode gets the Settings default', () async {
      settings.continuous = false;
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.viewMode.value, PdfViewMode.horizontal);
    });

    test('a toggle made before the default loads is not overridden by it', () async {
      controller.onInit();
      controller.toggleViewMode();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.viewMode.value, PdfViewMode.horizontal);
    });

    test('toggling saves the mode with the position', () async {
      controller.pdf.debugSetPages(pageCount: 10, currentPage: 4);
      controller.toggleViewMode();
      await Future<void>.delayed(Duration.zero);
      expect(recents.lastReadingPosition, {'page_number': 4, 'page_count': 10, 'view_mode': 'horizontal'});
    });
  });

  group('view mode / thumbnails', () {
    test('toggleViewMode alternates between continuous and horizontal', () {
      expect(controller.viewMode.value, PdfViewMode.continuous);
      controller.toggleViewMode();
      expect(controller.viewMode.value, PdfViewMode.horizontal);
      controller.toggleViewMode();
      expect(controller.viewMode.value, PdfViewMode.continuous);
    });

    test('the mode picked in the toolbar becomes the default for PDFs opened later', () async {
      controller.toggleViewMode();
      await Future<void>.delayed(Duration.zero);
      expect(settings.continuous, isFalse);
      controller.toggleViewMode();
      await Future<void>.delayed(Duration.zero);
      expect(settings.continuous, isTrue);
    });

    test('toggleThumbnails flips the flag', () {
      expect(controller.showThumbnails.value, isFalse);
      controller.toggleThumbnails();
      expect(controller.showThumbnails.value, isTrue);
    });

    test('jumpToPage no-ops before the document is ready', () async {
      await controller.jumpToPage(3);
      expect(controller.currentPage.value, 1);
    });
  });

  group('delegation to DocumentInteractionController', () {
    test('isFavorite / toggleFavorite delegate to the shared interaction controller', () async {
      expect(controller.isFavorite, isFalse);
      await controller.toggleFavorite();
      expect(controller.isFavorite, isTrue);
    });

    testWidgets('share blocks on a missing file before reaching the share sheet', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = PdfReaderController(document: missingDocument, recentRepository: recents, interactions: interactions, settingsRepository: FixtureSettings());
      await missingController.share();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('openWith blocks on a missing file before reaching the chooser', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = PdfReaderController(document: missingDocument, recentRepository: recents, interactions: interactions, settingsRepository: FixtureSettings());
      await missingController.openWith();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
