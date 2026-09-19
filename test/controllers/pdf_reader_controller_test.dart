import 'dart:io';

import 'package:customer/core/domain/models/document_category.dart';
import 'package:customer/core/domain/models/document_model.dart';
import 'package:customer/core/domain/repositories/favorite_repository.dart';
import 'package:customer/core/domain/repositories/recent_repository.dart';
import 'package:customer/core/domain/usecase/usecase.dart';
import 'package:customer/core/presentation/controllers/document_interaction_controller.dart';
import 'package:customer/core/presentation/utils/state_status.dart';
import 'package:customer/features/pdf_reader/presentation/pdf_reader_controller.dart';
import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

// pdfrx's PdfTextSearcher can only be constructed once PdfViewerController is
// attached to a live, loaded PdfViewer widget (see PdfReaderController's own
// doc comment on its `textSearcher` field) - something this environment can't
// render (no native PDFium available; see the PDF reader's implementation
// notes for the documented gap). So `onViewerReady` is never invoked here and
// `textSearcher.value` stays null throughout - these tests cover only the
// logic that doesn't require a rendered document: initial-position restore,
// debounced position saving, and delegation to DocumentInteractionController.

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

  @override
  ResultFuture<Map<String, Object?>> getPosition(String documentId) async => Right(position);

  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async {
    markOpenedCalls++;
    lastMarkedId = documentId;
    lastReadingPosition = readingPosition;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late DocumentModel document;
  late DocumentModel missingDocument;
  late FixtureRecents recents;
  late DocumentInteractionController interactions;
  late PdfReaderController controller;

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
    controller = PdfReaderController(document: document, recentRepository: recents, interactions: interactions);
  });

  tearDown(() async {
    Get.reset();
    await root.delete(recursive: true);
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
        controller.onPageChanged(5);
        expect(controller.currentPage.value, 5);
        expect(recents.markOpenedCalls, 0);

        async.elapse(const Duration(seconds: 1));
        expect(recents.markOpenedCalls, 0);

        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        expect(recents.markOpenedCalls, 1);
        expect(recents.lastMarkedId, document.id);
        expect(recents.lastReadingPosition, {'page_number': 5});
      });
    });

    test('a new page change resets the debounce and only the latest page is saved', () {
      fakeAsync((async) {
        controller.onPageChanged(2);
        async.elapse(const Duration(seconds: 1));
        controller.onPageChanged(3);
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        expect(recents.markOpenedCalls, 0);

        async.elapse(const Duration(seconds: 1));
        expect(recents.markOpenedCalls, 1);
        expect(recents.lastReadingPosition, {'page_number': 3});
      });
    });

    test('a null page (no current page yet) is ignored', () {
      fakeAsync((async) {
        controller.onPageChanged(null);
        expect(controller.currentPage.value, 1);
        async.elapse(const Duration(seconds: 3));
        expect(recents.markOpenedCalls, 0);
      });
    });

    test('onClose is a no-op when the viewer was never attached', () {
      expect(controller.pageCount.value, 0);
      expect(controller.textSearcher.value, isNull);
      expect(controller.onClose, returnsNormally);
      expect(recents.markOpenedCalls, 0);
    });

    test('onClose persists the current page once the document is ready', () async {
      controller.pageCount.value = 3;
      controller.currentPage.value = 3;
      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(recents.markOpenedCalls, 1);
      expect(recents.lastReadingPosition, {'page_number': 3});
    });
  });

  group('view mode / thumbnails', () {
    test('toggleViewMode alternates between continuous and horizontal', () {
      expect(controller.viewMode.value, PdfReaderViewMode.continuous);
      controller.toggleViewMode();
      expect(controller.viewMode.value, PdfReaderViewMode.horizontal);
      controller.toggleViewMode();
      expect(controller.viewMode.value, PdfReaderViewMode.continuous);
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
      final missingController = PdfReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.share();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('openWith blocks on a missing file before reaching the chooser', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final missingController = PdfReaderController(document: missingDocument, recentRepository: recents, interactions: interactions);
      await missingController.openWith();
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
