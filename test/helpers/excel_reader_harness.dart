import 'dart:io';
import 'dart:typed_data';

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
import 'package:openreader/features/excel_reader/presentation/excel_reader_controller.dart';
import 'package:openreader/features/excel_reader/presentation/excel_reader_view.dart';
import 'package:path/path.dart' as p;

class _Favorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  ResultFuture<void> toggle(String documentId) async => const Right(null);
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

/// Opens the Excel reader on a real file, as its binding does: writes
/// [bytes] to [root]/[name], registers the controller with Get (which
/// starts the load) and waits for it. In a widget test, call it inside
/// `tester.runAsync`.
Future<ExcelReaderController> openExcelReader(Directory root, String name, Uint8List bytes) async {
  final file = File(p.join(root.path, name))..writeAsBytesSync(bytes);
  final interactions = DocumentInteractionController(favoriteRepository: _Favorites(), recentRepository: _Recents());
  Get.put(interactions);
  final controller = ExcelReaderController(
    document: DocumentModel(
      id: file.path,
      path: file.path,
      displayName: name,
      extension: p.extension(name).substring(1),
      category: DocumentCategory.excel,
      sizeBytes: bytes.length,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    ),
    recentRepository: _Recents(),
    interactions: interactions,
  );
  Get.put(controller);
  for (var i = 0; i < 100 && controller.status.value.isBusy; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return controller;
}

/// Pumps the loaded reader's screen in a window of [size].
Future<void> showExcelReader(WidgetTester tester, ExcelReaderController controller, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  expect(controller.status.value, StateStatus.success);
  await tester.pumpWidget(
    GetMaterialApp(
      // Tapped cells don't leave a splash running (it trips a framework
      // assertion when the cell scrolls away mid-splash).
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const ExcelReaderView(),
    ),
  );
  await tester.pumpAndSettle();
}
