import 'package:customer/core/domain/models/document_category.dart';
import 'package:customer/core/domain/models/document_model.dart';
import 'package:customer/core/domain/repositories/favorite_repository.dart';
import 'package:customer/core/domain/repositories/recent_repository.dart';
import 'package:customer/core/domain/usecase/usecase.dart';
import 'package:customer/core/presentation/controllers/document_interaction_controller.dart';
import 'package:customer/core/presentation/utils/state_status.dart';
import 'package:customer/features/file_information/presentation/file_information_controller.dart';
import 'package:customer/services/utilities/file_metadata_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);

  @override
  ResultFuture<void> toggle(String documentId) async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureMetadataService implements FileMetadataService {
  FileMetadata? result;

  @override
  Future<FileMetadata?> read({required String path, required String extension, required DocumentCategory category}) async => result;
}

void main() {
  final document = DocumentModel(
    id: '/fixtures/report.pdf',
    path: '/fixtures/report.pdf',
    displayName: 'report.pdf',
    extension: 'pdf',
    category: DocumentCategory.pdf,
    sizeBytes: 100,
    modifiedAt: DateTime(2026),
    lastSeenAt: DateTime(2026),
  );

  late FixtureMetadataService metadataService;
  late DocumentInteractionController interactions;
  late FileInformationController controller;

  setUp(() {
    Get.testMode = true;
    metadataService = FixtureMetadataService();
    interactions = DocumentInteractionController(
      favoriteRepository: FixtureFavorites(),
      recentRepository: FixtureRecents(),
    );
    controller = FileInformationController(
      document: document,
      metadataService: metadataService,
      interactions: interactions,
    );
  });

  tearDown(() => Get.reset());

  test('load() succeeds and exposes fresh metadata when the file exists', () async {
    metadataService.result = FileMetadata(
      path: document.path,
      extension: document.extension,
      category: document.category,
      sizeBytes: 200,
      modifiedAt: DateTime(2026, 2),
    );

    await controller.load();

    expect(controller.status.value, StateStatus.success);
    expect(controller.metadata.value?.sizeBytes, 200);
    expect(controller.errorMessage.value, isNull);
  });

  test('load() reports the BRD 9.16 missing-file error when the file is gone', () async {
    metadataService.result = null;

    await controller.load();

    expect(controller.status.value, StateStatus.error);
    expect(controller.metadata.value, isNull);
    expect(controller.errorMessage.value, 'This file may have been moved or deleted.');
  });

  test('onInit triggers an initial load', () async {
    metadataService.result = FileMetadata(
      path: document.path,
      extension: document.extension,
      category: document.category,
      sizeBytes: 1,
      modifiedAt: DateTime(2026),
    );
    final freshController = FileInformationController(
      document: document,
      metadataService: metadataService,
      interactions: interactions,
    );
    freshController.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(freshController.status.value, StateStatus.success);
  });

  test('toggleFavorite and isFavorite delegate to the shared interaction controller', () async {
    expect(controller.isFavorite, isFalse);
    await controller.toggleFavorite();
    expect(controller.isFavorite, isTrue);
  });
}
