import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/data/repositories/app_settings_repository_impl.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/features/pdf_reader/presentation/pdf_reader_controller.dart';
import 'package:openreader/features/settings/presentation/settings_controller.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_document_viewer/pdf.dart' show PdfViewMode;

class _Favorites implements FavoriteRepository {
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

/// CR-SETTINGS-UX N3: Settings and readers that are already open follow each other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SettingsController settings;
  late TextReaderController text;
  late PdfReaderController pdf;
  var textClosed = false;
  final repo = AppSettingsRepositoryImpl();

  DocumentModel doc(String path, String ext, DocumentCategory category) => DocumentModel(
        id: path,
        path: path,
        displayName: path.split('/').last,
        extension: ext,
        category: category,
        sizeBytes: 1,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    textClosed = false;
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('openreader-live-sync-');
    final file = File('${root.path}/a.txt')..writeAsStringSync('one\ntwo');
    final interactions = DocumentInteractionController(favoriteRepository: _Favorites(), recentRepository: _Recents());
    settings = SettingsController(recents: _Recents())..onInit();
    text = TextReaderController(
      document: doc(file.path, 'txt', DocumentCategory.text),
      recentRepository: _Recents(),
      interactions: interactions,
      settingsRepository: repo,
    )..onInit();
    pdf = PdfReaderController(
      document: doc('${root.path}/missing.pdf', 'pdf', DocumentCategory.pdf),
      recentRepository: _Recents(),
      interactions: interactions,
      settingsRepository: repo,
    )..onInit();
    await settle();
  });

  tearDown(() async {
    if (!textClosed) text.onClose();
    pdf.onClose();
    settings.onClose();
    Get.reset();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('a change in Settings reaches an open reader', () {
    test('night mode, in every reader', () async {
      expect(text.nightMode.value, isFalse);
      await settings.setNightMode(true);
      expect(text.nightMode.value, isTrue);
      expect(pdf.nightMode.value, isTrue);
      await settings.setNightMode(false);
      expect(text.nightMode.value, isFalse);
    });

    test('text size and line wrap', () async {
      final before = text.fontSize.value;
      await settings.setFontSize(before + 4);
      expect(text.fontSize.value, before + 4);
      await settings.setLineWrap(false);
      expect(text.lineWrap.value, isFalse);
      expect(text.plainText?.wrap, isFalse);
      // A later load of the saved value cannot undo it.
      await settle();
      expect(text.fontSize.value, before + 4);
    });

    test('PDF default mode switches an open PDF, and only when it differs', () async {
      expect(pdf.pdf.viewMode, PdfViewMode.continuous);
      await settings.setPdfContinuous(true);
      expect(pdf.pdf.viewMode, PdfViewMode.continuous, reason: 'already that mode: untouched');
      await settings.setPdfContinuous(false);
      expect(pdf.pdf.viewMode, PdfViewMode.horizontal);
      await settings.setPdfContinuous(true);
      expect(pdf.pdf.viewMode, PdfViewMode.continuous);
    });

    test('a closed reader no longer listens', () async {
      text.onClose();
      textClosed = true;
      final before = text.fontSize.value;
      await settings.setFontSize(before + 2);
      expect(text.fontSize.value, before);
    });
  });

  group('a toolbar change reaches Settings, with no tab switch', () {
    test('night mode, text size, wrap and PDF mode', () async {
      text.toggleNightMode();
      expect(settings.nightMode.value, isTrue);

      text.increaseFontSize();
      expect(settings.fontSize.value, text.fontSize.value);

      text.toggleLineWrap();
      expect(settings.lineWrap.value, text.lineWrap.value);

      pdf.toggleViewMode();
      expect(settings.pdfContinuous.value, isFalse);
      pdf.toggleViewMode();
      expect(settings.pdfContinuous.value, isTrue);
    });

    test('and an open reader follows another reader', () {
      pdf.toggleNightMode();
      expect(text.nightMode.value, isTrue);
    });
  });

  test('with no change, nothing moves', () async {
    final size = text.fontSize.value;
    final wrap = text.lineWrap.value;
    await settle();
    expect(text.fontSize.value, size);
    expect(text.lineWrap.value, wrap);
    expect(text.nightMode.value, isFalse);
    expect(pdf.pdf.viewMode, PdfViewMode.continuous);
  });
}
