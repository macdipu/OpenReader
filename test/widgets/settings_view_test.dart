import 'dart:io';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/data/repositories/app_settings_repository_impl.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/controllers/theme_controller.dart';
import 'package:openreader/core/presentation/controllers/thumbnail_preferences.dart';
import 'package:openreader/core/presentation/widgets/document/document_list_tile.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/features/settings/presentation/sections/settings_widgets.dart';
import 'package:openreader/features/settings/presentation/sections/permissions_section.dart';
import 'package:openreader/core/presentation/theme/app_theme.dart';
import 'package:openreader/core/presentation/widgets/app_shortcuts.dart';
import 'package:openreader/features/settings/presentation/settings_controller.dart';
import 'package:openreader/features/settings/presentation/settings_maintenance.dart';
import 'package:openreader/features/settings/presentation/settings_view.dart';
import 'package:openreader/services/platform_integration/default_app_service.dart';
import 'package:openreader/services/utilities/path_service.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CR-SETTINGS-UX WP-C: section visibility per platform and width, permission states, default-app
/// status, two-way sync with the repository, the shortcut and the limits.

class FakeStorage implements StorageAccessService {
  FakeStorage(this.current);
  StorageAccessState current;
  int requests = 0;
  int opened = 0;
  int allFiles = 0;

  @override
  Future<StorageAccessState> state() async => current;
  @override
  Future<bool> requestOrOpenSettings() async {
    requests++;
    return false;
  }

  @override
  Future<bool> openSettings() async {
    opened++;
    return true;
  }

  @override
  Future<bool> openAllFilesAccessSettings() async {
    allFiles++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDefaultApp implements DefaultAppService {
  FakeDefaultApp([Map<DocumentType, DefaultStatus>? statuses]) : statuses = statuses ?? {};
  final Map<DocumentType, DefaultStatus> statuses;
  final made = <Set<DocumentType>>[];
  int resets = 0;
  int openedSystem = 0;
  int queries = 0;

  @override
  bool get isSupported => true;
  @override
  Future<Map<DocumentType, DefaultStatus>> queryDefaults() async {
    queries++;
    return {for (final t in DocumentType.values) t: statuses[t] ?? DefaultStatus.unknown};
  }

  @override
  Future<DefaultAppResult> makeDefault(Set<DocumentType> types) async {
    made.add(types);
    return const DefaultAppResult(applied: true, success: true, message: 'done');
  }

  @override
  Future<void> resetPrompt() async => resets++;
  @override
  Future<bool> openSystemDefaultAppsSettings() async {
    openedSystem++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecents implements RecentRepository {
  final cutoffs = <DateTime>[];
  int cleared = 0;
  @override
  ResultFuture<void> clearAll() async {
    cleared++;
    return const Right(null);
  }

  @override
  ResultFuture<void> removeOlderThan(DateTime cutoff) async {
    cutoffs.add(cutoff);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TempPathService implements PathService {
  _TempPathService(this.dir);
  final Directory dir;
  @override
  ResultFuture<Directory> getTempDirectory() async => Right(dir);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

String _texts(Element e) {
  final out = <String>[];
  void v(Element x) {
    if (x.widget is Text) out.add((x.widget as Text).data ?? '');
    x.visitChildren(v);
  }
  v(e);
  return out.join('|');
}

void main() {
  final repo = AppSettingsRepositoryImpl();

  late FakeStorage storage;
  late FakeDefaultApp defaultApp;
  late FakeRecents recents;

  Future<SettingsController> pump(
    WidgetTester tester, {
    required TargetPlatform platform,
    required double width,
    double height = 8000,
    Map<String, Object> prefs = const {},
    StorageAccessState access = StorageAccessState.allowed,
    Map<DocumentType, DefaultStatus>? defaults,
    Future<bool> Function(String url)? openUrl,
    Future<void> Function(String text)? share,
    double textScale = 1,
    PathService? pathService,
  }) async {
    Get.reset();
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(prefs);
    PackageInfo.setMockInitialValues(
        appName: 'OpenReader', packageName: 'p', version: '1.2', buildNumber: '3', buildSignature: '');
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    storage = FakeStorage(access);
    defaultApp = FakeDefaultApp(defaults);
    recents = FakeRecents();
    Get.put(ThemeController());
    final controller = SettingsController(
      pathService: pathService,
      storageAccess: storage,
      defaultApp: defaultApp,
      recents: recents,
      share: share ?? (_) async {},
      openUrl: openUrl ?? (_) async => true,
    );
    Get.put(controller);
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
      home: const SettingsView(embedded: true),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  /// Lets real I/O started by a tap finish, pumping in between, until [done] holds.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Lets a snackbar's timers finish.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  const mobile = [TargetPlatform.android, TargetPlatform.iOS];
  const desktop = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux];

  group('section visibility', () {
    // Single column: the labels are on screen at 360 and 700 px.
    for (final platform in [...mobile, ...desktop]) {
      for (final width in [360.0, 700.0]) {
        testWidgets('$platform at ${width.toInt()}px: one column in the platform order', (tester) async {
          await pump(tester, platform: platform, width: width);
          final isMobile = mobile.contains(platform);
          final expected = isMobile
              ? ['Permissions', 'Reading', 'Appearance', 'Files & storage', 'Privacy', 'Open with', 'Help & about']
              : ['File handling', 'Reading', 'Appearance', 'Files & storage', 'Privacy', 'Keyboard shortcuts', 'Help & about'];
          final hidden = isMobile ? ['File handling', 'Keyboard shortcuts'] : ['Permissions', 'Open with'];
          final ys = <double>[];
          for (final label in expected) {
            expect(find.text(label), findsOneWidget, reason: label);
            ys.add(tester.getTopLeft(find.text(label)).dy);
          }
          expect(ys, [...ys]..sort(), reason: 'sections follow the platform order');
          for (final label in hidden) {
            expect(find.text(label), findsNothing, reason: label);
          }
          expect(find.byKey(const ValueKey('settings-section-list')), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('$platform at 1200px: two panes with the platform section list', (tester) async {
        await pump(tester, platform: platform, width: 1200, height: 1400);
        final isMobile = mobile.contains(platform);
        final expected = isMobile
            ? ['Permissions', 'Reading', 'Appearance', 'Files & storage', 'Privacy', 'Open with', 'Help & about']
            : ['File handling', 'Reading', 'Appearance', 'Files & storage', 'Privacy', 'Keyboard shortcuts', 'Help & about'];
        final hidden = isMobile ? ['File handling', 'Keyboard shortcuts'] : ['Permissions', 'Open with'];
        final list = find.byKey(const ValueKey('settings-section-list'));
        expect(list, findsOneWidget);
        for (final title in expected) {
          expect(find.descendant(of: list, matching: find.text(title)), findsOneWidget, reason: title);
        }
        for (final title in hidden) {
          expect(find.descendant(of: list, matching: find.text(title)), findsNothing, reason: title);
        }
        // The first section of the platform is on the right.
        expect(find.byKey(ValueKey('settings-pane-${isMobile ? 'permissions' : 'fileHandling'}')), findsOneWidget);
      });
    }
  });

  group('permissions', () {
    testWidgets('Android allowed: label, and the action opens the app settings', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360);
      expect(find.text('Allowed'), findsOneWidget);
      expect(find.textContaining('limited mode'), findsWidgets); // the note
      await tester.tap(find.text('Manage in app settings'));
      await tester.pump();
      expect(storage.opened, 1);
      expect(storage.requests, 0);
    });

    testWidgets('Android not allowed: label, and the action asks for access', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
      expect(find.text('Not allowed (limited mode)'), findsOneWidget);
      await tester.tap(find.text('Allow file access'));
      await tester.pump();
      expect(storage.requests, 1);
      expect(storage.opened, 0);
    });

    testWidgets('Android blocked: label, then explain and open the app settings', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.blocked);
      expect(find.text('Blocked'), findsOneWidget);
      await tester.tap(find.text('Open settings to allow'));
      await tester.pumpAndSettle();
      expect(storage.allFiles, 0, reason: 'explained first');
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      expect(storage.allFiles, 1);
      expect(storage.opened, 0);
    });

    testWidgets('Android: a status that cannot be read shows no status', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notApplicable);
      for (final label in ['Allowed', 'Blocked', 'Not allowed (limited mode)']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('App permissions'), findsOneWidget);
    });

    testWidgets('the status refreshes when the app resumes', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
      expect(find.text('Not allowed (limited mode)'), findsOneWidget);
      storage.current = StorageAccessState.allowed;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets('iOS: App permissions opens the app settings and no status shows', (tester) async {
      await pump(tester, platform: TargetPlatform.iOS, width: 360);
      for (final label in ['Allowed', 'Blocked', 'Not allowed (limited mode)']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.textContaining('Files app'), findsWidgets);
      await tester.tap(find.text('App permissions'));
      await tester.pump();
      expect(storage.opened, 1);
    });
  });

  group('file handling', () {
    testWidgets('status per type; unknown shows none; Set and Set all call makeDefault', (tester) async {
      await pump(tester, platform: TargetPlatform.macOS, width: 1200, height: 1600, defaults: {
        DocumentType.pdf: DefaultStatus.isDefault,
        DocumentType.word: DefaultStatus.otherApp,
      });
      expect(find.byKey(const ValueKey('default-status-pdf')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('default-status-pdf'))).data, 'Default');
      expect(tester.widget<Text>(find.byKey(const ValueKey('default-status-word'))).data, 'Other app');
      for (final t in DocumentType.values.where((t) => t != DocumentType.pdf && t != DocumentType.word)) {
        expect(find.byKey(ValueKey('default-status-${t.name}')), findsNothing, reason: t.name);
        expect(find.byKey(ValueKey('set-default-${t.name}')), findsOneWidget, reason: 'button without status');
      }
      expect(find.byKey(const ValueKey('set-default-pdf')), findsNothing, reason: 'already the default');

      await tester.tap(find.byKey(const ValueKey('set-default-word')));
      await tester.pumpAndSettle();
      expect(defaultApp.made.single, {DocumentType.word});
      await tester.tap(find.text('Set all'));
      await tester.pumpAndSettle();
      expect(defaultApp.made.last, DocumentType.values.toSet());
      await drain(tester);
    });

    testWidgets('Windows has the system settings link, Ask me again resets the prompt', (tester) async {
      await pump(tester, platform: TargetPlatform.windows, width: 1200, height: 1600);
      await tester.tap(find.text('Open system default-apps settings'));
      await tester.pump();
      expect(defaultApp.openedSystem, 1);
      await tester.tap(find.text('Ask me again'));
      await tester.pump();
      expect(defaultApp.resets, 1);
      await drain(tester);
    });

    testWidgets('Linux and macOS have no system settings link', (tester) async {
      await pump(tester, platform: TargetPlatform.linux, width: 1200, height: 1600);
      expect(find.text('Open system default-apps settings'), findsNothing);
    });
  });

  group('settings and the repository agree', () {
    testWidgets('settings change the repository', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.text('Page by page'));
      await tester.tap(find.text('Night mode'));
      await tester.tap(find.byTooltip('Larger text'));
      await tester.tap(find.text('Wrap long lines'));
      await tester.tap(find.text('Restore last position'));
      await tester.pump();
      expect(c.pdfContinuous.value, isFalse);
      await tester.runAsync(() async {
        expect(await repo.getDefaultContinuousScroll(), isFalse);
        expect(await repo.getReaderNightMode(), isTrue);
        expect(await repo.getTextReaderFontSize(), 18);
        expect(await repo.getTextReaderLineWrap(), isFalse);
        expect(await repo.getRestoreReadingPosition(), isFalse);
      });
      expect(tester.widget<Text>(find.byKey(const ValueKey('font-size-value'))).data, '18 pt');
      expect(tester.widget<Text>(find.byKey(const ValueKey('font-sample'))).style!.fontSize, 18);
    });

    testWidgets('values saved by a reader toolbar show in Settings after it reloads', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(c.nightMode.value, isFalse);
      await tester.runAsync(() async {
        // What the readers write from their toolbars.
        await repo.setReaderNightMode(true);
        await repo.setDefaultContinuousScroll(false);
        await repo.setTextReaderFontSize(24);
        await repo.setTextReaderLineWrap(false);
        await c.reload();
      });
      await tester.pump();
      expect(c.nightMode.value, isTrue);
      expect(c.pdfContinuous.value, isFalse);
      expect(c.fontSize.value, 24);
      expect(c.lineWrap.value, isFalse);
      expect(tester.widget<Text>(find.byKey(const ValueKey('font-size-value'))).data, '24 pt');
    });

    testWidgets('saved values are shown when Settings opens', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, prefs: {
        'app_settings:pdf_night_mode': true,
        'app_settings:text_reader_font_size': 20.0,
        'app_settings:restore_reading_position': false,
      });
      await tester.pump();
      expect(c.nightMode.value, isTrue);
      expect(c.fontSize.value, 20);
      expect(c.restorePosition.value, isFalse);
    });

    testWidgets('theme choice goes through the ThemeController and the repository', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(Get.find<ThemeController>().themeMode, ThemeMode.dark);
      await tester.runAsync(() async => expect((await repo.getThemeMode()).name, 'dark'));
    });
  });

  group('privacy', () {
    testWidgets('states always-on Firebase collection, with no switches or policy link', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.textContaining('Google Firebase'), findsOneWidget);
      expect(find.textContaining('never uploaded'), findsOneWidget);
      expect(find.textContaining('always collected'), findsOneWidget);
      expect(find.textContaining('Debug builds send nothing'), findsOneWidget);
      expect(find.text('Send crash reports'), findsNothing);
      expect(find.text('Share usage analytics'), findsNothing);
      expect(find.textContaining('Privacy Policy'), findsNothing);
      // Firebase uses a random installation identifier: the statement must not claim anonymity.
      expect(find.textContaining('nonymous'), findsNothing);
      expect(find.textContaining('random installation identifier'), findsOneWidget);
    });
  });

  group('storage limits', () {
    testWidgets('history retention is saved and enforced; Off stops recording and deletes nothing', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.text('30 days'));
      await tester.pump();
      await tester.runAsync(() async {
        expect(await repo.getHistoryRetentionDays(), 30);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(recents.cutoffs, hasLength(1));
      final age = DateTime.now().difference(recents.cutoffs.single);
      expect(age.inDays, 30);

      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(find.textContaining('where you stopped reading'), findsWidgets);
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel')); // keep the existing history
      await tester.pumpAndSettle();
      await tester.runAsync(() async => expect(await repo.getHistoryRetentionDays(), 0));
      expect(recents.cutoffs, hasLength(1));
      expect(recents.cleared, 0);
    });

    testWidgets('picking Off asks first; Cancel keeps the previous value', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, prefs: {
        'app_settings:history_retention_days': 30,
      });
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(find.text('Turn off reading history?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.historyRetentionDays.value, 30);
      await tester.runAsync(() async => expect(await repo.getHistoryRetentionDays(), 30));
      expect(recents.cleared, 0);
    });

    testWidgets('picking Off can also clear the existing history', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(find.text('Also clear existing history?'), findsOneWidget);
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      expect(c.historyRetentionDays.value, 0);
      expect(recents.cleared, 1);
    });

    test('trimRenderCachesToCap trims only the render cache, oldest first', () async {
      final temp = Directory.systemTemp.createTempSync('cache_roots');
      addTearDown(() => temp.deleteSync(recursive: true));
      final base = DateTime(2026);
      File write(String path, int day) {
        final f = File('${temp.path}/$path')
          ..createSync(recursive: true)
          ..writeAsBytesSync(List.filled(100, 1));
        f.setLastModifiedSync(base.add(Duration(days: day)));
        return f;
      }

      final t0 = write('document_thumbnails/a.png', 0);
      final t1 = write('document_thumbnails/b.png', 1);
      final t2 = write('document_thumbnails/c.png', 2);
      final incoming = write('incoming/old.pdf', -100);
      final update = write('openreader_update/setup.exe', -100);
      final stray = write('other.bin', -100);

      expect(await trimRenderCachesToCap(temp, 150), 200);
      expect(t0.existsSync(), isFalse);
      expect(t1.existsSync(), isFalse);
      expect(t2.existsSync(), isTrue);
      expect(incoming.existsSync(), isTrue);
      expect(update.existsSync(), isTrue);
      expect(stray.existsSync(), isTrue);
      expect(await trimRenderCachesToCap(temp, 150), 0, reason: 'within the cap');
      expect(await trimRenderCachesToCap(Directory('${temp.path}/missing'), 0), 0, reason: 'missing dir');
    });

    testWidgets('fixStorageAccess does what the state calls for', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      c.storageState.value = StorageAccessState.notAllowed;
      storage.current = StorageAccessState.notAllowed;
      await c.fixStorageAccess();
      expect(storage.requests, 1);
      expect(storage.opened, 0);

      storage.current = StorageAccessState.allowed;
      c.storageState.value = StorageAccessState.allowed;
      await c.fixStorageAccess();
      expect(storage.opened, 1);

      storage.current = StorageAccessState.blocked;
      c.storageState.value = StorageAccessState.blocked;
      final pending = c.fixStorageAccess();
      await tester.pumpAndSettle();
      expect(storage.allFiles, 0, reason: 'explains first');
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      await pending;
      expect(storage.allFiles, 1);
      expect(storage.opened, 1);
      expect(storage.requests, 1);

      c.storageState.value = null;
      await c.fixStorageAccess();
      expect(storage.requests, 1);
      expect(storage.opened, 1);
    });

    testWidgets('cache cap is saved', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.byKey(const ValueKey('cache-cap-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('500 MB'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => expect(await repo.getCacheCapMb(), 500));
      await tester.tap(find.byKey(const ValueKey('cache-cap-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No limit'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => expect(await repo.getCacheCapMb(), isNull));
    });

    test('enforceHistoryRetention: forever and off delete nothing', () async {
      for (final days in [null, 0]) {
        SharedPreferences.setMockInitialValues({if (days != null) 'app_settings:history_retention_days': days});
        final fake = FakeRecents();
        expect(await enforceHistoryRetention(settings: repo, recents: fake), isFalse);
        expect(fake.cutoffs, isEmpty);
      }
    });

    test('enforceHistoryRetention deletes older than the cutoff', () async {
      SharedPreferences.setMockInitialValues({'app_settings:history_retention_days': 30});
      final fake = FakeRecents();
      final now = DateTime(2026, 6);
      expect(await enforceHistoryRetention(settings: repo, recents: fake, now: now), isTrue);
      expect(fake.cutoffs.single, DateTime(2026, 5, 2));
    });

    test('trimDirectoryToCap removes the oldest files first and keeps the rest', () async {
      final dir = Directory.systemTemp.createTempSync('cap_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final base = DateTime(2026);
      for (var i = 0; i < 4; i++) {
        final f = File('${dir.path}/f$i')..writeAsBytesSync(List.filled(100, i));
        f.setLastModifiedSync(base.add(Duration(days: i)));
      }
      final removed = await trimDirectoryToCap(dir, 250);
      expect(removed, 200);
      expect(File('${dir.path}/f0').existsSync(), isFalse);
      expect(File('${dir.path}/f1').existsSync(), isFalse);
      expect(File('${dir.path}/f2').existsSync(), isTrue);
      expect(File('${dir.path}/f3').existsSync(), isTrue);
      expect(await trimDirectoryToCap(dir, 250), 0, reason: 'already within the cap');
      expect(await trimDirectoryToCap(Directory('${dir.path}/missing'), 0), 0);
    });
  });

  group('two-pane keyboard', () {
    testWidgets('arrow keys move between sections, Tab moves into the controls', (tester) async {
      await pump(tester, platform: TargetPlatform.windows, width: 1200, height: 1400);
      final list = find.byKey(const ValueKey('settings-section-list'));
      await tester.tap(find.descendant(of: list, matching: find.text('File handling')));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-pane-shortcuts')), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Ctrl+,'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-pane-privacy')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('settings section list'));
    });

    testWidgets('macOS lists Cmd shortcuts', (tester) async {
      await pump(tester, platform: TargetPlatform.macOS, width: 1200, height: 1400);
      final list = find.byKey(const ValueKey('settings-section-list'));
      await tester.tap(find.descendant(of: list, matching: find.text('Keyboard shortcuts')));
      await tester.pump();
      expect(find.text('Cmd+,'), findsOneWidget);
      expect(find.text('Cmd+O'), findsOneWidget);
    });
  });

  group('Ctrl/Cmd+, shortcut', () {
    for (final key in [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.metaLeft]) {
      testWidgets('${key.keyLabel} + comma opens Settings', (tester) async {
        var opened = 0;
        await tester.pumpWidget(MaterialApp(
          home: AppShortcuts(onOpenSettings: () => opened++, child: const Scaffold(body: Text('page'))),
        ));
        await tester.pump();
        await tester.sendKeyDownEvent(key);
        await tester.sendKeyEvent(LogicalKeyboardKey.comma);
        await tester.sendKeyUpEvent(key);
        expect(opened, 1);
      });
    }

    test('it is in the shortcuts list', () {
      final entry = appShortcutReference.firstWhere((s) => s.key == ',');
      expect(entry.label(macOS: true), 'Cmd+,');
      expect(entry.label(macOS: false), 'Ctrl+,');
    });
  });

  group('help and about', () {
    testWidgets('has Send feedback, Rate (Android), Share, welcome screens and reset', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.text('Share app'), findsOneWidget);
      expect(find.text('Show welcome screens again'), findsOneWidget);
      expect(find.text('Reset all settings'), findsOneWidget);
      expect(find.text('Open-source licenses'), findsOneWidget);
      expect(find.text('Send feedback'), findsOneWidget);
      expect(find.textContaining('Rate'), findsOneWidget, reason: 'Android has the Play Store page');
      expect(find.text('v1.2 (3)'), findsOneWidget);
    });

    testWidgets('welcome screens again: confirmed sets onboarding incomplete', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, prefs: {
        'app_settings:onboarding_complete': true,
      });
      await tester.tap(find.text('Show welcome screens again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => expect(await repo.hasCompletedOnboarding(), isTrue));
      await tester.tap(find.text('Show welcome screens again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show again'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => expect(await repo.hasCompletedOnboarding(), isFalse));
      await drain(tester);
    });

    testWidgets('reset all settings: confirmed restores defaults, keeps onboarding', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, prefs: {
        'app_settings:onboarding_complete': true,
        'app_settings:auto_scanned': true,
        'app_settings:pdf_night_mode': true,
      });
      await tester.pump();
      expect(c.nightMode.value, isTrue);
      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await repo.getReaderNightMode(), isNull);
        expect(await repo.hasCompletedOnboarding(), isTrue);
        expect(await repo.hasAutoScanned(), isTrue);
      });
      await tester.pump();
      expect(c.nightMode.value, isFalse);
      await drain(tester);
    });
  });

  group('rate and share', () {
    testWidgets('Android: Rate opens the Play Store page', (tester) async {
      final opened = <String>[];
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, openUrl: (url) async {
        opened.add(url);
        return true;
      });
      await tester.tap(find.text('Rate OpenReader'));
      await tester.pump();
      expect(opened, ['https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader']);
    });

    testWidgets('Android: a store that cannot be opened shows an error, no crash', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, openUrl: (_) async => false);
      await tester.tap(find.text('Rate OpenReader'));
      await tester.pump();
      expect(find.text('Could not open the Play Store.'), findsOneWidget);
      await drain(tester);
    });

    for (final platform in [TargetPlatform.iOS, ...desktop]) {
      testWidgets('$platform has no Rate row', (tester) async {
        await pump(tester, platform: platform, width: 1200, height: 3000);
        expect(find.text('Rate OpenReader'), findsNothing);
        expect(SettingsController.canRateApp, isFalse);
      });
    }

    for (final platform in [...mobile, ...desktop]) {
      testWidgets('$platform: Share app includes the Play Store link', (tester) async {
        final shared = <String>[];
        final c = await pump(tester, platform: platform, width: 1200, height: 3000, share: (t) async => shared.add(t));
        await c.shareApp();
        expect(shared.single, contains(SettingsController.playStoreUrl));
        expect(shared.single, contains('OpenReader'));
      });
    }
  });

  group('How to allow it yourself', () {
    testWidgets('collapsed when allowed; tapping expands it', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.textContaining('Android 11 or newer'), findsNothing);
      await tester.tap(find.text('How to allow it yourself'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Android 11 or newer'), findsOneWidget);
    });

    testWidgets('open from the start when access is blocked', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, access: StorageAccessState.blocked);
      await tester.pumpAndSettle();
      expect(find.textContaining('Android 11 or newer'), findsOneWidget);
      expect(find.text('Open All files access'), findsOneWidget);
    });

    testWidgets('the buttons open the All files page and the app settings', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, access: StorageAccessState.blocked);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open All files access'));
      await tester.pumpAndSettle();
      expect(storage.allFiles, 1);
      expect(storage.opened, 0);
      await tester.tap(find.text('Open app settings'));
      await tester.pumpAndSettle();
      expect(storage.opened, 1);
      expect(storage.allFiles, 1);
    });

    testWidgets('shown when the state cannot be read, with the app settings row', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, access: StorageAccessState.notApplicable);
      expect(find.byType(HowToAllowAccess), findsOneWidget);
    });
  });

  group('StorageAccessService.openAllFilesAccessSettings', () {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    late List<String> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'requestPermissions') return {for (final p in call.arguments as List) p as int: 0};
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: requests All files access, the page that holds the switch', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await StorageAccessService.instance.openAllFilesAccessSettings(), isTrue);
      expect(calls, ['requestPermissions']);
    });

    test('elsewhere: falls back to the app settings page', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await StorageAccessService.instance.openAllFilesAccessSettings(), isTrue);
      expect(calls, ['openAppSettings']);
    });
  });

  group('N5 macOS: status re-read after the OS confirms', () {
    testWidgets('one extra refresh about 1.5 s after Set', (tester) async {
      await pump(tester, platform: TargetPlatform.macOS, width: 1200, height: 1600);
      final before = defaultApp.queries;
      await tester.tap(find.byKey(const ValueKey('set-default-pdf')));
      await tester.pump();
      final afterSet = defaultApp.queries;
      expect(afterSet, greaterThan(before));
      await tester.pump(const Duration(milliseconds: 1400));
      expect(defaultApp.queries, afterSet, reason: 'not yet');
      await tester.pump(const Duration(milliseconds: 200));
      expect(defaultApp.queries, afterSet + 1);
      await drain(tester);
    });

    testWidgets('cancelled when the controller is disposed first', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.macOS, width: 1200, height: 1600);
      await tester.tap(find.byKey(const ValueKey('set-default-pdf')));
      await tester.pump();
      final afterSet = defaultApp.queries;
      c.onClose();
      await tester.pump(const Duration(seconds: 3));
      expect(defaultApp.queries, afterSet);
      await drain(tester);
    });

    testWidgets('other desktops do not re-read', (tester) async {
      await pump(tester, platform: TargetPlatform.linux, width: 1200, height: 1600);
      await tester.tap(find.byKey(const ValueKey('set-default-pdf')));
      await tester.pump();
      final afterSet = defaultApp.queries;
      await tester.pump(const Duration(seconds: 3));
      expect(defaultApp.queries, afterSet);
      await drain(tester);
    });
  });

  group('hide thumbnails (ST-19)', () {
    final doc = DocumentModel(
      id: '/fixtures/report.pdf',
      path: '/fixtures/report.pdf',
      displayName: 'report.pdf',
      extension: 'pdf',
      category: DocumentCategory.pdf,
      sizeBytes: 100,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

    tearDown(() => ThumbnailPreferences.hidden.value = false);

    testWidgets('Privacy has the switch, off by default; it saves and reaches the rows', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(c.hideThumbnails.value, isFalse);
      expect(tester.widget<Switch>(find.descendant(of: find.widgetWithText(SettingsSwitchRow, 'Hide thumbnails'), matching: find.byType(Switch))).value, isFalse);
      await tester.tap(find.text('Hide thumbnails'));
      await tester.pump();
      expect(c.hideThumbnails.value, isTrue);
      expect(ThumbnailPreferences.hidden.value, isTrue);
      await tester.runAsync(() async => expect(await repo.getHideThumbnails(), isTrue));
      await tester.tap(find.text('Hide thumbnails'));
      await tester.pump();
      expect(ThumbnailPreferences.hidden.value, isFalse);
      await tester.runAsync(() async => expect(await repo.getHideThumbnails(), isFalse));
    });

    testWidgets('a saved choice is applied when Settings loads; reset clears it', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, prefs: {
        'app_settings:hide_thumbnails': true,
      });
      await tester.pump();
      expect(c.hideThumbnails.value, isTrue);
      expect(ThumbnailPreferences.hidden.value, isTrue);
      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(c.hideThumbnails.value, isFalse);
      expect(ThumbnailPreferences.hidden.value, isFalse);
      await drain(tester);
    });

    testWidgets('document rows show the format icon when on, and follow the switch live', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DocumentListTile(document: doc, isFavorite: false, onTap: () {}, onToggleFavorite: (_) {}),
        ),
      ));
      await tester.pump();
      const iconKey = ValueKey('thumbnail-format-icon');
      expect(find.byKey(iconKey), findsNothing);
      ThumbnailPreferences.hidden.value = true;
      await tester.pump();
      expect(find.byKey(iconKey), findsOneWidget);
      expect(find.descendant(of: find.byKey(iconKey), matching: find.byIcon(doc.category.icon)), findsOneWidget);
      ThumbnailPreferences.hidden.value = false;
      await tester.pump();
      expect(find.byKey(iconKey), findsNothing);
    });

    test('ThumbnailPreferences.load reads the saved choice', () async {
      SharedPreferences.setMockInitialValues({'app_settings:hide_thumbnails': true});
      await ThumbnailPreferences.load(repo);
      expect(ThumbnailPreferences.hidden.value, isTrue);
    });
  });

  group('accessibility (N4)', () {
    testWidgets('segmented tiles without an icon are at least 48dp tall', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SettingsSegmented<int>(
            value: 1,
            choices: const [SettingsChoice(1, 'Forever'), SettingsChoice(2, '30 days'), SettingsChoice(3, 'Off')],
            onChanged: (_) {},
          ),
        ),
      ));
      for (final label in ['Forever', '30 days', 'Off']) {
        final tile = find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer));
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('a switch row is one semantics node: title, subtitle, state and toggle', (tester) async {
      final handle = tester.ensureSemantics();
      var value = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SettingsSwitchRow(
              icon: Icons.nightlight_outlined,
              title: 'Night mode',
              subtitle: 'Dark pages',
              value: value,
              onChanged: (v) => value = v),
        ),
      ));
      var matching = 0;
      void walk(SemanticsNode node) {
        if (node.label.contains('Night mode') || node.label.contains('Dark pages')) matching++;
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      expect(matching, 1, reason: 'title and subtitle in one node, not repeated by the switch');
      final node = tester.getSemantics(find.byType(SettingsSwitchRow));
      expect(node.label, allOf(contains('Night mode'), contains('Dark pages')));
      expect(node, containsSemantics(hasToggledState: true, isToggled: false, hasTapAction: true));
      handle.dispose();
    });

    for (final scale in [1.5, 2.0]) {
      for (final platform in [...mobile, ...desktop]) {
        testWidgets('$platform at 360px, text x$scale: no overflow, targets >= 48dp', (tester) async {
          await pump(tester, platform: platform, width: 360, height: 800, textScale: scale);
          expect(tester.takeException(), isNull);
          for (final finder in [find.byType(InkWell), find.byType(IconButton), find.byType(ButtonStyleButton)]) {
            for (final element in finder.evaluate()) {
              final box = element.renderObject! as RenderBox;
              if (!box.hasSize) continue;
              // A button's own ink area sits inside the padded target that is measured with it.
              var insideButton = false;
              element.visitAncestorElements((a) {
                if (a.widget is IconButton || a.widget is ButtonStyleButton) insideButton = true;
                return !insideButton;
              });
              if (element.widget is InkWell && insideButton) continue;
              expect(box.size.height, greaterThanOrEqualTo(48), reason: '${element.widget.runtimeType} ${(element.renderObject as RenderBox).localToGlobal(Offset.zero)} ${(element.renderObject as RenderBox).size} ${_texts(element)}');
            }
          }
          // Scroll through the page: nothing overflows further down either.
          final scrollable = find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(scrollable, const Offset(0, -600));
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('standard UX: cache cap picker (4+ options)', () {
    for (final platform in mobile) {
      testWidgets('$platform: a row with the current value opens a bottom sheet; the pick is saved', (tester) async {
        final c = await pump(tester, platform: platform, width: 360, height: 5000);
        final row = find.byKey(const ValueKey('cache-cap-picker'));
        expect(row, findsOneWidget);
        // Not a segmented row any more: the other options are not on the page.
        expect(find.text('500 MB'), findsNothing);
        expect(find.descendant(of: row, matching: find.text('No limit')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.byIcon(Icons.chevron_right_rounded)), findsOneWidget);

        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings-picker-sheet')), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byKey(const ValueKey('settings-picker-dialog')), findsNothing);
        expect(find.byType(RadioListTile<int>), findsNWidgets(4));
        for (final label in ['No limit', '100 MB', '500 MB', '1 GB']) {
          expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(label)), findsOneWidget, reason: label);
        }

        await tester.tap(find.text('1 GB'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing, reason: 'closes on pick, no Save step');
        expect(c.cacheCapMb.value, 1024);
        await tester.runAsync(() async => expect(await repo.getCacheCapMb(), 1024));
        expect(find.descendant(of: row, matching: find.text('1 GB')), findsOneWidget);
      });
    }

    for (final platform in desktop) {
      testWidgets('$platform: the row opens a dialog; Cancel keeps the value, a pick is saved', (tester) async {
        final c = await pump(tester, platform: platform, width: 1200, height: 1400);
        final list = find.byKey(const ValueKey('settings-section-list'));
        await tester.tap(find.descendant(of: list, matching: find.text('Files & storage')));
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('cache-cap-picker'));
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings-picker-dialog')), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(c.cacheCapMb.value, isNull);

        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.text('100 MB'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings-picker-dialog')), findsNothing);
        await tester.runAsync(() async => expect(await repo.getCacheCapMb(), 100));
        expect(tester.widget<Text>(find.byKey(const ValueKey('settings-picker-value'))).data, '100 MB');
      });
    }

    testWidgets('a saved value is shown and pre-selected in the picker', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, prefs: {'app_settings:cache_cap_mb': 500});
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('settings-picker-value'))).data, '500 MB');
      await tester.tap(find.byKey(const ValueKey('cache-cap-picker')));
      await tester.pumpAndSettle();
      final group = tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>));
      expect(group.groupValue, 2);
    });

    testWidgets('2-3 option choices stay segmented', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.byType(SettingsSegmented<ThemeMode>), findsOneWidget);
      expect(find.byType(SettingsSegmented<bool>), findsOneWidget);
      expect(find.byType(SettingsSegmented<int?>), findsOneWidget, reason: 'history retention');
    });
  });

  group('standard UX: status is never colour only', () {
    for (final (state, label, kind) in [
      (StorageAccessState.allowed, 'Allowed', 'ok'),
      (StorageAccessState.notAllowed, 'Not allowed (limited mode)', 'warning'),
      (StorageAccessState.blocked, 'Blocked', 'blocked'),
    ]) {
      testWidgets('file access $label has its icon and text', (tester) async {
        await pump(tester, platform: TargetPlatform.android, width: 360, access: state);
        expect(tester.widget<Text>(find.byKey(const ValueKey('file-access-status'))).data, label);
        final status = find.ancestor(of: find.byKey(const ValueKey('file-access-status')), matching: find.byType(SettingsStatus));
        expect(find.descendant(of: status, matching: find.byKey(ValueKey('settings-status-icon-$kind'))), findsOneWidget);
      });
    }

    testWidgets('file handling Default and Other app each have an icon and text', (tester) async {
      await pump(tester, platform: TargetPlatform.linux, width: 1200, height: 1600, defaults: {
        DocumentType.pdf: DefaultStatus.isDefault,
        DocumentType.word: DefaultStatus.otherApp,
      });
      for (final (type, label, kind) in [(DocumentType.pdf, 'Default', 'ok'), (DocumentType.word, 'Other app', 'neutral')]) {
        final text = find.byKey(ValueKey('default-status-${type.name}'));
        expect(tester.widget<Text>(text).data, label);
        final status = find.ancestor(of: text, matching: find.byType(SettingsStatus));
        expect(find.descendant(of: status, matching: find.byKey(ValueKey('settings-status-icon-$kind'))), findsOneWidget);
      }
    });
  });

  group('standard UX: sentence-case section headers', () {
    testWidgets('headers are sentence case and announced as headings', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      for (final title in ['Permissions', 'Reading', 'Files & storage', 'Help & about']) {
        expect(find.text(title.toUpperCase()), findsNothing, reason: title);
        final label = find.descendant(of: find.byType(SettingsSectionLabel), matching: find.text(title));
        expect(label, findsOneWidget, reason: title);
        expect(tester.getSemantics(label), isSemantics(isHeader: true), reason: title);
      }
      handle.dispose();
    });
  });

  group('standard UX: destructive actions confirm, then say what happened', () {
    testWidgets('clear history: error-coloured confirm, Cancel keeps it, Clear shows the success message', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.text('Clear reading history'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all reading history?'), findsOneWidget);
      final confirm = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Clear'));
      final ctx = tester.element(find.text('Clear all reading history?'));
      expect(confirm.style?.foregroundColor?.resolve({}), Theme.of(ctx).colorScheme.error);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(recents.cleared, 0);

      await tester.tap(find.text('Clear reading history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(recents.cleared, 1);
      expect(find.text(SettingsController.historyClearedMessage), findsOneWidget);
      await drain(tester);
    });

    testWidgets('clear render cache: asks first, then reports how much was freed', (tester) async {
      final temp = Directory.systemTemp.createTempSync('settings_cache');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/document_thumbnails/a.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(2048, 1));
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, pathService: _TempPathService(temp));
      await tester.tap(find.text('Clear render cache'));
      await tester.pumpAndSettle();
      expect(find.text('Clear render cache?'), findsOneWidget);
      final confirm = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Clear'));
      expect(confirm.style?.foregroundColor?.resolve({}), AppTheme.lightTheme.colorScheme.error);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(File('${temp.path}/document_thumbnails/a.png').existsSync(), isTrue, reason: 'Cancel keeps the cache');

      await tester.tap(find.text('Clear render cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await settle(tester, () => find.text(SettingsController.cacheClearedMessage(2048)).evaluate().isNotEmpty);
      expect(File('${temp.path}/document_thumbnails/a.png').existsSync(), isFalse);
      expect(find.text(SettingsController.cacheClearedMessage(2048)), findsOneWidget);
      await drain(tester);
    });

    testWidgets('reset all settings: error-coloured confirm, then the success message', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      final confirm = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reset'));
      expect(confirm.style?.foregroundColor?.resolve({}), AppTheme.lightTheme.colorScheme.error);
      await tester.tap(find.text('Reset'));
      await settle(tester, () => find.text(SettingsController.resetMessage).evaluate().isNotEmpty);
      expect(find.text(SettingsController.resetMessage), findsOneWidget);
      await drain(tester);
    });

    testWidgets('action rows that only act carry no chevron', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      for (final title in ['Clear reading history', 'Reset all settings', 'Show welcome screens again']) {
        final row = find.ancestor(of: find.text(title), matching: find.byType(SettingsActionRow));
        expect(find.descendant(of: row, matching: find.byIcon(Icons.chevron_right_rounded)), findsNothing, reason: title);
      }
    });
  });

  group('standard UX: desktop section list', () {
    testWidgets('selected item: selected semantics, indicator bar and bold; arrows move it', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, platform: TargetPlatform.windows, width: 1200, height: 1400);
      SemanticsNode tile(String name) => tester.getSemantics(find.byKey(ValueKey('settings-section-tile-$name')));
      expect(tile('fileHandling'), isSemantics(isSelected: true, isButton: true, label: 'File handling'));
      expect(tile('reading'), isSemantics(isSelected: false, isButton: true, label: 'Reading'));
      final indicator = find.byKey(const ValueKey('settings-section-indicator'));
      expect(indicator, findsOneWidget);
      expect(find.ancestor(of: indicator, matching: find.byKey(const ValueKey('settings-section-tile-fileHandling'))), findsOneWidget);
      final list = find.byKey(const ValueKey('settings-section-list'));
      expect(tester.widget<Text>(find.descendant(of: list, matching: find.text('File handling'))).style?.fontWeight, FontWeight.w700);
      expect(tester.widget<Text>(find.descendant(of: list, matching: find.text('Reading'))).style?.fontWeight, FontWeight.w400);

      await tester.tap(find.descendant(of: list, matching: find.text('File handling')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tile('reading'), isSemantics(isSelected: true));
      expect(tile('fileHandling'), isSemantics(isSelected: false));
      handle.dispose();
    });

    testWidgets('focus ring shows on keyboard focus only', (tester) async {
      await pump(tester, platform: TargetPlatform.linux, width: 1200, height: 1400);
      final list = find.byKey(const ValueKey('settings-section-list'));
      bool ringOn(String name) => tester
          .widget<SettingsFocusRing>(find.descendant(
              of: find.byKey(ValueKey('settings-section-tile-$name')), matching: find.byType(SettingsFocusRing)))
          .focused;
      await tester.tap(find.descendant(of: list, matching: find.text('File handling')));
      await tester.pump();
      expect(ringOn('fileHandling'), isFalse, reason: 'a tap shows no ring');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(ringOn('reading'), isTrue);
      expect(ringOn('fileHandling'), isFalse);
    });

    testWidgets('list items are at least 40dp tall', (tester) async {
      await pump(tester, platform: TargetPlatform.macOS, width: 1200, height: 1400);
      for (final name in ['fileHandling', 'reading', 'about']) {
        expect(tester.getSize(find.byKey(ValueKey('settings-section-tile-$name'))).height, greaterThanOrEqualTo(40));
      }
    });
  });

  group('standard UX: rows', () {
    testWidgets('a switch row toggles from anywhere on the row and is one keyboard stop', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(c.lineWrap.value, isTrue);
      await tester.tap(find.text('In text files'));
      await tester.pump();
      expect(c.lineWrap.value, isFalse);
      final row = find.ancestor(of: find.text('Wrap long lines'), matching: find.byType(SettingsSwitchRow));
      expect(find.descendant(of: row, matching: find.byType(ExcludeFocus)), findsOneWidget);
    });

    testWidgets('an action row is one semantics node with its name and tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      final node = tester.getSemantics(find.text('Share app'));
      expect(node, isSemantics(label: 'Share app', isButton: true, hasTapAction: true));
      final picker = tester.getSemantics(find.text('Cache size limit'));
      expect(picker.label, allOf(contains('Cache size limit'), contains('No limit')));
      expect(picker, isSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });

    test('text and status tokens meet WCAG AA (4.5:1) in light and dark', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final cs = theme.colorScheme;
        final pairs = <String, (Color, Color)>{
          'onSurface/card': (cs.onSurface, cs.surfaceContainerLowest),
          'onSurfaceVariant/card': (cs.onSurfaceVariant, cs.surfaceContainerLowest),
          'onSurfaceVariant/page': (cs.onSurfaceVariant, cs.surface),
          'secondary/card': (cs.secondary, cs.surfaceContainerLowest),
          'error/card': (cs.error, cs.surfaceContainerLowest),
          'onSecondaryContainer/selected': (cs.onSecondaryContainer, cs.secondaryContainer),
        };
        pairs.forEach((name, pair) {
          expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5), reason: '${theme.brightness.name} $name');
        });
        // The focus ring and selected indicator are non-text UI: 3:1.
        expect(_contrast(cs.secondary, cs.secondaryContainer), greaterThanOrEqualTo(3), reason: '${theme.brightness.name} indicator');
      }
    });
  });

  group('send feedback', () {
    for (final platform in [...mobile, ...desktop]) {
      testWidgets('$platform shows Send feedback', (tester) async {
        await pump(tester, platform: platform, width: 360, height: 8000);
        expect(find.text('Send feedback'), findsOneWidget);
        expect(find.text('Opens a GitHub issue (needs a free GitHub account)'), findsOneWidget);
      });
    }

    testWidgets('opens a pre-filled GitHub issue with version and OS, no document path', (tester) async {
      final opened = <String>[];
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, openUrl: (url) async {
        opened.add(url);
        return true;
      });
      await tester.pump();
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      final uri = Uri.parse(opened.single);
      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(uri.path, '/macdipu/OpenReader/issues/new');
      final body = uri.queryParameters['body']!;
      expect(body, contains('What happened?'));
      expect(body, contains('1.2 (3)'));
      expect(body, contains(Platform.operatingSystem));
      expect(body, contains('android'));
      expect(uri.queryParameters['title'], startsWith('Feedback'));
      expect(opened.single, isNot(contains(' ')), reason: 'URL-encoded');
    });

    test('the body holds only version, OS and platform', () {
      final uri = SettingsController.feedbackUri(
          appVersion: '1.0.21 (21)', osName: 'linux', osVersion: 'Linux 6.8', platform: 'linux');
      final body = uri.queryParameters['body']!;
      expect(body, contains('1.0.21 (21)'));
      expect(body, contains('Linux 6.8'));
      for (final banned in ['/home', '/storage', '.pdf', '.docx', 'file://']) {
        expect(body, isNot(contains(banned)), reason: banned);
      }
    });

    testWidgets('a page that cannot be opened shows an error, no crash', (tester) async {
      await pump(tester, platform: TargetPlatform.windows, width: 360, height: 8000, openUrl: (_) async => false);
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Could not open the feedback page.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await drain(tester);
    });
  });
}
