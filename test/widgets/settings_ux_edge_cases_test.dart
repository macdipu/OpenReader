import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/app/shell/app_shell.dart';
import 'package:openreader/app/shell/app_shell_controller.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:openreader/core/domain/repositories/favorite_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/document_interaction_controller.dart';
import 'package:openreader/core/presentation/controllers/theme_controller.dart';
import 'package:openreader/core/presentation/theme/app_theme.dart';
import 'package:openreader/core/presentation/utils/state_status.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_controller.dart';
import 'package:openreader/features/text_reader/presentation/text_reader_view.dart';
import 'package:openreader/res/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _ReaderSettings implements AppSettingsRepository {
  @override
  Future<bool> getRestoreReadingPosition() async => true;
  @override
  Future<double?> getTextReaderFontSize() async => null;
  @override
  Future<bool?> getTextReaderLineWrap() async => null;
  @override
  Future<bool?> getReaderNightMode() async => null;
  @override
  Future<void> setTextReaderFontSize(double value) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// CR-SETTINGS-UX review gaps: the Ctrl/Cmd+, decision, BRD 9.18 "theme changes while a reader is
/// active".
void main() {
  group('Ctrl/Cmd+, in the shell (openSettingsShortcut)', () {
    late List<int> tabs;
    late List<String> pushed;

    void press({required bool wide, required String route}) => openSettingsShortcut(
          wide: wide,
          currentRoute: route,
          changeTab: tabs.add,
          push: pushed.add,
        );

    setUp(() {
      tabs = [];
      pushed = [];
    });

    test('wide shell: selects the Settings tab and pushes nothing', () {
      press(wide: true, route: '/');
      expect(tabs, [AppShellController.settingsIndex]);
      expect(pushed, isEmpty);
    });

    test('narrow shell: pushes the Settings route', () {
      press(wide: false, route: '/');
      expect(pushed, [AppRoutes.settings]);
      expect(tabs, isEmpty);
    });

    test('narrow shell already on Settings: does not push again', () {
      press(wide: false, route: AppRoutes.settings);
      press(wide: false, route: AppRoutes.settings);
      expect(pushed, isEmpty);
      expect(tabs, isEmpty);
    });
  });

  Future<(TextReaderController, Directory)> openReader(WidgetTester tester, {required String subdirectory}) async {
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('openreader-edge-')))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/$subdirectory/note.txt');
    await tester.runAsync(() async {
      await file.create(recursive: true);
      await file.writeAsString('first line\nsecond line');
    });
    final controller = Get.put(TextReaderController(
      document: DocumentModel(
        id: file.path,
        path: file.path,
        displayName: 'note.txt',
        extension: 'txt',
        category: DocumentCategory.text,
        sizeBytes: 1,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      ),
      recentRepository: _Recents(),
      interactions: DocumentInteractionController(favoriteRepository: _Favorites(), recentRepository: _Recents()),
      settingsRepository: _ReaderSettings(),
    ));
    return (controller, dir);
  }

  Future<void> loaded(WidgetTester tester, TextReaderController controller) async {
    for (var i = 0; i < 50 && controller.status.value.isBusy; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pumpAndSettle();
  }

  group('theme changes while a reader is active', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      testWidgets('a reader keeps its content when the theme becomes $mode', (tester) async {
        Get.reset();
        Get.testMode = true;
        SharedPreferences.setMockInitialValues({});
        final theme = Get.put(ThemeController());
        final (controller, _) = await openReader(tester, subdirectory: 'docs');
        await tester.pumpWidget(GetMaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const TextReaderView(),
        ));
        await loaded(tester, controller);
        expect(find.text('first line'), findsOneWidget);
        Brightness brightness() => Theme.of(tester.element(find.text('first line'))).brightness;
        expect(brightness(), Brightness.light);

        await tester.runAsync(() => theme.changeThemeMode(mode));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('first line'), findsOneWidget);
        expect(find.text('second line'), findsOneWidget);
        if (mode == ThemeMode.dark) expect(brightness(), Brightness.dark);
        if (mode == ThemeMode.light) expect(brightness(), Brightness.light);

        // The reader is still usable.
        controller.increaseFontSize();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      });
    }
  });
}
