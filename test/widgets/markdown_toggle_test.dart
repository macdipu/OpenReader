import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_controller.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_view.dart';
import 'package:universal_document_viewer/markdown.dart' show MarkdownViewMode;

class _Favorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recents implements RecentRepository {
  @override
  ResultFuture<Map<String, Object?>> getPosition(String documentId) async => const Right({});
  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) async =>
      const Right(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;

  setUp(() async {
    Get.testMode = true;
    dir = await Directory.systemTemp.createTemp('openreader-md-toggle-');
  });

  tearDown(() async {
    Get.reset();
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Windows can hold the file a moment longer.
    }
  });

  Future<TextReaderController> open(WidgetTester tester, String name) async {
    final file = File('${dir.path}/$name');
    await tester.runAsync(() => file.writeAsString('# Title\n\nSome *text*.'));
    final extension = name.split('.').last;
    final recents = _Recents();
    final controller = Get.put(
      TextReaderController(
        document: DocumentModel(
          id: file.path,
          path: file.path,
          displayName: name,
          extension: extension,
          category: DocumentCategory.text,
          sizeBytes: 20,
          modifiedAt: DateTime(2026),
          lastSeenAt: DateTime(2026),
        ),
        recentRepository: recents,
        interactions: DocumentInteractionController(favoriteRepository: _Favorites(), recentRepository: recents),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: TextReaderView()));
    for (var i = 0; i < 100 && controller.status.value.isBusy; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pumpAndSettle();
    expect(controller.status.value, StateStatus.success);
    return controller;
  }

  testWidgets('Markdown opens in Preview; one button cycles Preview, Code, Split, Preview', (tester) async {
    final controller = await open(tester, 'notes.md');
    expect(controller.viewMode.value, MarkdownViewMode.preview);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(controller.viewMode.value, MarkdownViewMode.code);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.code_rounded));
    await tester.pumpAndSettle();
    expect(controller.viewMode.value, MarkdownViewMode.split);
    expect(find.byIcon(Icons.vertical_split_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.vertical_split_rounded));
    await tester.pumpAndSettle();
    expect(controller.viewMode.value, MarkdownViewMode.preview);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('a plain text file has no view toggle', (tester) async {
    await open(tester, 'notes.txt');
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.code_rounded), findsNothing);
    expect(find.byIcon(Icons.vertical_split_rounded), findsNothing);
  });
}
