import 'dart:io';

import 'package:customer/core/domain/models/document_category.dart';
import 'package:customer/core/domain/models/document_model.dart';
import 'package:customer/core/domain/repositories/favorite_repository.dart';
import 'package:customer/core/domain/repositories/recent_repository.dart';
import 'package:customer/core/domain/usecase/usecase.dart';
import 'package:customer/core/presentation/controllers/document_interaction_controller.dart';
import 'package:customer/res/routes/app_routes.dart';
import 'package:customer/services/utilities/storage_access_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  int markOpenedCalls = 0;
  int removeCalls = 0;
  String? lastRemovedId;

  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async {
    markOpenedCalls++;
    return const Right(null);
  }

  @override
  ResultFuture<void> remove(String documentId) async {
    removeCalls++;
    lastRemovedId = documentId;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureAccess implements StorageAccessService {
  bool granted = true;
  int requestCalls = 0;

  @override
  Future<bool> hasAccess() async => granted;

  @override
  Future<bool> requestAccess() async {
    requestCalls++;
    return granted;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late File existingFile;
  late DocumentModel accessibleDocument;
  late DocumentModel missingDocument;
  late FixtureRecents recents;
  late FixtureAccess access;
  late DocumentInteractionController controller;

  DocumentModel documentFor(String path, {DocumentCategory category = DocumentCategory.pdf}) => DocumentModel(
        id: path,
        path: path,
        displayName: p.basename(path),
        extension: switch (category) {
          DocumentCategory.pdf => 'pdf',
          DocumentCategory.word => 'docx',
          DocumentCategory.excel => 'xlsx',
          DocumentCategory.powerpoint => 'pptx',
          DocumentCategory.text => 'txt',
          DocumentCategory.csv => 'csv',
          DocumentCategory.unknown => '',
        },
        category: category,
        sizeBytes: 10,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );

  setUp(() async {
    Get.testMode = true;
    root = await Directory.systemTemp.createTemp('opendocs-interaction-');
    existingFile = File(p.join(root.path, 'report.pdf'));
    await existingFile.writeAsString('fixture');
    accessibleDocument = documentFor(existingFile.path);
    missingDocument = documentFor(p.join(root.path, 'missing.pdf'));

    recents = FixtureRecents();
    access = FixtureAccess();
    controller = DocumentInteractionController(
      favoriteRepository: FixtureFavorites(),
      recentRepository: recents,
      storageAccess: access,
    );
  });

  tearDown(() async {
    Get.reset();
    await root.delete(recursive: true);
  });

  Future<void> pumpWithSnackbarHost(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
  }

  /// GetX's snackbar combines a real auto-dismiss Timer with an
  /// AnimationController; neither pumpAndSettle() nor a manual
  /// closeAllSnackbars() reliably drains both before a test ends in this
  /// environment (leaves a dangling ticker/timer that fails the test during
  /// teardown even when every assertion already passed). A single pump
  /// covering the full 3s auto-dismiss duration plus its exit animation
  /// does drain it cleanly - verified against this get/flutter_test version
  /// pairing before adopting it here.
  Future<void> drainSnackbar(WidgetTester tester) => tester.pump(const Duration(seconds: 4));

  group('openDocument accessibility guard (ODF-021/023)', () {
    testWidgets('records the open and proceeds when the file is accessible (non-reader stub path)', (tester) async {
      // PowerPoint/Text/CSV have no reader yet, so openDocument() still
      // records the open itself and shows the stub message. PDF/Word/Excel's
      // own dispatch (tested separately below) does not call markOpened
      // here - each reader owns that, so this test deliberately uses a
      // still-stubbed category to exercise the stub path.
      final pptDocument = documentFor(existingFile.path, category: DocumentCategory.powerpoint);
      await pumpWithSnackbarHost(tester);
      await controller.openDocument(pptDocument);
      await tester.pump();
      expect(recents.markOpenedCalls, 1);
      await drainSnackbar(tester);
    });

    testWidgets('dispatches an accessible PDF/Word/Excel document to its own reader route', (tester) async {
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const Scaffold(body: SizedBox())),
          GetPage(name: AppRoutes.pdfReader, page: () => const Scaffold(body: Text('pdf reader stand-in'))),
          GetPage(name: AppRoutes.wordReader, page: () => const Scaffold(body: Text('word reader stand-in'))),
          GetPage(name: AppRoutes.excelReader, page: () => const Scaffold(body: Text('excel reader stand-in'))),
        ],
      ));

      await controller.openDocument(accessibleDocument);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.pdfReader);
      expect(find.text('pdf reader stand-in'), findsOneWidget);

      final wordDocument = documentFor(existingFile.path, category: DocumentCategory.word);
      await controller.openDocument(wordDocument);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.wordReader);
      expect(find.text('word reader stand-in'), findsOneWidget);

      final excelDocument = documentFor(existingFile.path, category: DocumentCategory.excel);
      await controller.openDocument(excelDocument);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.excelReader);
      expect(find.text('excel reader stand-in'), findsOneWidget);

      // Each reader owns markOpened() itself (initial restore + debounced
      // persistence); a bare call here would reset an existing position.
      expect(recents.markOpenedCalls, 0);
    });

    testWidgets('blocks and offers Remove from Recents when the file is missing', (tester) async {
      await pumpWithSnackbarHost(tester);
      await controller.openDocument(missingDocument);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(recents.markOpenedCalls, 0);
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      expect(find.text('Remove from Recents'), findsOneWidget);

      await tester.tap(find.text('Remove from Recents'));
      await tester.pump();
      expect(recents.removeCalls, 1);
      expect(recents.lastRemovedId, missingDocument.id);
      await drainSnackbar(tester);
    });

    testWidgets('blocks and offers Grant Access when storage permission is lost', (tester) async {
      access.granted = false;
      await pumpWithSnackbarHost(tester);
      await controller.openDocument(accessibleDocument);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(recents.markOpenedCalls, 0);
      expect(find.text('OpenDocs no longer has access to this file.'), findsOneWidget);
      expect(find.text('Grant Access'), findsOneWidget);

      await tester.tap(find.text('Grant Access'));
      await tester.pump();
      expect(access.requestCalls, 1);
      await drainSnackbar(tester);
    });
  });

  group('shareDocument / openWithExternalApp guard', () {
    // These only exercise the guard's early-return path. The accessible
    // (happy) path calls a real platform plugin (share_plus / open_filex)
    // with no test-time channel mock registered here, so it is intentionally
    // left to device verification rather than asserted in this suite.
    testWidgets('shareDocument blocks on a missing file before reaching the share sheet', (tester) async {
      await pumpWithSnackbarHost(tester);
      await controller.shareDocument(missingDocument);
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await drainSnackbar(tester);
    });

    testWidgets('openWithExternalApp blocks on a missing file before reaching the chooser', (tester) async {
      await pumpWithSnackbarHost(tester);
      await controller.openWithExternalApp(missingDocument);
      await tester.pump();
      expect(find.text('This file may have been moved or deleted.'), findsOneWidget);
      await drainSnackbar(tester);
    });
  });
}
