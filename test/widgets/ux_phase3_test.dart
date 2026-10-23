import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:openreader/app/shell/app_shell_controller.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/core/presentation/widgets/app_shortcuts.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_controller.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_view.dart';
import 'package:openreader/services/platform_integration/incoming_intent_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/features/file_information/presentation/file_information_controller.dart';
import 'package:openreader/features/file_information/presentation/file_information_view.dart';
import 'package:openreader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:openreader/features/onboarding/presentation/onboarding_view.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/presentation/utils/document_date_formatter.dart';
import 'package:openreader/core/presentation/widgets/document/document_list_tile.dart';
import 'package:openreader/core/presentation/widgets/empty/common_empty_view.dart';
import 'package:openreader/core/presentation/widgets/snackbar/custom_snackbar.dart';
import 'package:openreader/features/search/presentation/search_controller.dart';
import 'package:openreader/features/search/presentation/search_view.dart';
import 'package:openreader/services/utilities/file_metadata_service.dart';

/// CR-OPENREADER-UX Phase 3 regressions.

final sample = DocumentModel(
  id: '/fixtures/report.pdf',
  path: '/fixtures/report.pdf',
  displayName: 'report.pdf',
  extension: 'pdf',
  category: DocumentCategory.pdf,
  sizeBytes: 100,
  modifiedAt: DateTime(2026, 10, 22),
  lastSeenAt: DateTime(2026, 10, 22),
);

class FixtureFavorites implements FavoriteRepository {
  @override
  ResultFuture<List<DocumentModel>> getFavorites() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureRecents implements RecentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureDocuments implements DocumentRepository {
  @override
  ResultFuture<List<DocumentModel>> getDocuments(
          {DocumentCategory? category, String? query, DocumentSortMode sort = DocumentSortMode.nameAsc}) async =>
      Right([sample]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureMetadata implements FileMetadataService {
  @override
  Future<FileMetadata?> read({required String path, required String extension, required DocumentCategory category}) async =>
      FileMetadata(path: path, extension: extension, category: category, sizeBytes: 100, modifiedAt: DateTime(2026, 10, 22));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(DocumentInteractionController(favoriteRepository: FixtureFavorites(), recentRepository: FixtureRecents()));
  });
  tearDown(Get.reset);

  group('A. trust and copy', () {
    testWidgets('File Information: no placeholder rows, no sandbox or "verified" claims (UX-23/24)', variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Get.put(FileInformationController(document: sample, metadataService: FixtureMetadata()));
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: FileInformationSheet())));
      await tester.pumpAndSettle();

      expect(find.text('Not available'), findsNothing);
      expect(find.textContaining('andbox'), findsNothing);
      expect(find.textContaining('verified'), findsNothing);
      expect(find.text('OFFLINE'), findsNothing);
      expect(find.text("Read via Android's All Files Access"), findsOneWidget);
      expect(find.textContaining('network'), findsNothing);
    });

    testWidgets('onboarding on desktop: welcome with Get started, no permission step (UX-27)',
        variant: TargetPlatformVariant.desktop(), (tester) async {
      Get.put(OnboardingController());
      await tester.pumpWidget(const GetMaterialApp(home: OnboardingView()));
      expect(find.widgetWithText(FilledButton, 'Get started'), findsOneWidget);
      expect(find.text('Allow Access'), findsNothing);
      expect(find.text('Not Now'), findsNothing);
      expect(find.textContaining('All Files Access'), findsNothing);
      expect(find.textContaining('this computer'), findsOneWidget);
      // No reader exists for PowerPoint (UX-07 open), so it isn't claimed.
      expect(find.textContaining('PowerPoint'), findsNothing);
    });

    testWidgets('onboarding on Android keeps the All Files Access disclosure, without overflowing (UX-27/31)',
        variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      Get.put(OnboardingController());
      await tester.pumpWidget(const GetMaterialApp(home: OnboardingView()));
      expect(find.widgetWithText(FilledButton, 'Allow Access'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
      expect(find.textContaining('"All Files Access"'), findsOneWidget);
    });
  });

  group('B. shared UI', () {
    test('absolute document dates are locale-aware medium dates (UX-25)', () {
      expect(formatDocumentDate(DateTime(2026, 10, 22, 15, 30)), 'Oct 22, 2026');
    });

    test('title highlight marks every case-insensitive match (UX-25)', () {
      const match = TextStyle(fontWeight: FontWeight.w900);
      final span = highlightMatches('Report and REPORT', 'report', null, match);
      final parts = span.children!.cast<TextSpan>();
      expect(parts.map((p) => p.text), ['Report', ' and ', 'REPORT']);
      expect(parts.where((p) => p.style == match).length, 2);
      expect(highlightMatches('Report', '  ', null, match).children, isNull);
    });

    testWidgets('snackbars carry no generic title (UX-28)', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      CustomSnackbar.success('Saved.');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Success'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('empty states offer their way out (UX-29)', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CommonEmptyView(
            icon: Icons.star_outline_rounded,
            message: 'No favorite documents yet.',
            subtitle: 'Tap the star on any document to keep it here.',
            actionLabel: 'Browse Files',
            onAction: () => tapped = true,
          ),
        ),
      ));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Browse Files'));
      expect(tapped, isTrue);
    });

    testWidgets('format pills announce their selected state (UX-30)', (tester) async {
      final handle = tester.ensureSemantics();
      Get.put(SearchDocumentsController(documentRepository: FixtureDocuments()));
      await tester.pumpWidget(const GetMaterialApp(home: SearchView()));
      await tester.enterText(find.byType(TextField), 'rep');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('All Formats')),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.text('PDF').first),
        isSemantics(isButton: true, isSelected: false),
      );
      handle.dispose();
    });
  });

  group('D. opening files and desktop affordances (UX-34)', () {
    testWidgets('Ctrl and Cmd shortcuts open a file and search; Esc steps back', (tester) async {
      var opened = 0, searched = 0, escaped = 0;
      await tester.pumpWidget(MaterialApp(
        home: AppShortcuts(
          onOpenFile: () => opened++,
          onSearch: () => searched++,
          onEscape: () => escaped++,
          child: const Scaffold(body: SizedBox()),
        ),
      ));
      Future<void> chord(LogicalKeyboardKey modifier, LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(modifier);
      }

      await chord(LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyO);
      await chord(LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyO);
      await chord(LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyF);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(opened, 2);
      expect(searched, 1);
      expect(escaped, 1);
    });

    testWidgets('Esc in a reader closes its search first', (tester) async {
      final controller = Get.put(TextReaderController(
        document: sample,
        recentRepository: FixtureRecents(),
        interactions: Get.find<DocumentInteractionController>(),
      ));
      await tester.pumpWidget(const GetMaterialApp(home: TextReaderView()));
      for (var i = 0; i < 50 && controller.status.value.isBusy; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pumpAndSettle();
      controller.startSearching();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.isSearching.value, isFalse);
    });

    testWidgets('right-clicking a document row opens its actions menu', (tester) async {
      var shared = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DocumentListTile(
            document: sample,
            isFavorite: false,
            onTap: () {},
            onToggleFavorite: (_) {},
            onShare: () => shared = true,
            onDelete: () {},
          ),
        ),
      ));
      await tester.tap(find.text('report.pdf'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(shared, isTrue);
    });

    testWidgets('dropped files: the first one goes through the normal open path', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      final incoming = FixtureIncoming();
      final shell = AppShellController(incomingIntentService: incoming);
      shell.isDraggingFile.value = true;
      await shell.openDroppedPaths(['/drop/a.pdf', '/drop/b.pdf']);
      await tester.pump(const Duration(milliseconds: 400));
      expect(incoming.paths, ['/drop/a.pdf']);
      expect(shell.isDraggingFile.value, isFalse);
      expect(find.text('Opened the first of 2 files.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}

class FixtureIncoming implements IncomingIntentService {
  final paths = <String>[];
  @override
  Future<void> handlePath(String path) async => paths.add(path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
