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
import 'package:openreader/core/presentation/controllers/dynamic_color_preferences.dart';
import 'package:openreader/core/presentation/controllers/reader_wakelock.dart';
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
import 'package:openreader/features/settings/presentation/settings_sections.dart';
import 'package:openreader/features/settings/presentation/settings_view.dart';
import 'package:openreader/services/platform_integration/default_app_service.dart';
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
  int stateReads = 0;
  int? sdk = 34;
  DeviceBrand brand = DeviceBrand.other;

  @override
  Future<int?> androidSdkInt() async => sdk;

  @override
  Future<DeviceBrand> deviceBrand() async => brand;

  @override
  Future<StorageAccessState> state() async {
    stateReads++;
    return current;
  }

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

/// A stand-in tonal palette for [DynamicColorPreferences.fromPrimaryTones]: the seed's hue at the
/// CIE lightness [tone] (what a Material tonal palette guarantees), built through HSL steps.
int _tone(Color seed, int tone) {
  final hsl = HSLColor.fromColor(seed);
  var best = hsl.withLightness(0).toColor();
  var bestDiff = double.infinity;
  for (var l = 0.0; l <= 1.0; l += 0.005) {
    final c = hsl.withLightness(l).toColor();
    final y = c.computeLuminance();
    final double lstar = y <= 216 / 24389 ? y * 24389 / 27 : 116 * pow(y, 1 / 3) - 16;
    final diff = (lstar - tone).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = c;
    }
  }
  return best.toARGB32();
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
  }) async {
    Get.reset();
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    // Closing the controller cancels its permission re-check timers.
    addTearDown(Get.reset);
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

  /// Lets the permission re-check timers (up to 3 s) finish, so no timer is pending at the end.
  Future<void> drainWatch(WidgetTester tester) => tester.pump(const Duration(seconds: 4));

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
              ? ['File access', 'Reading', 'Appearance', 'Privacy & data', 'About']
              : ['File handling', 'Reading', 'Appearance', 'Privacy & data', 'Keyboard shortcuts', 'About'];
          final hidden = isMobile
              ? ['File handling', 'Keyboard shortcuts', 'Files & storage', 'Data', 'Privacy', 'Open with', 'Permissions', 'Help & about']
              : ['File access', 'Files & storage', 'Data', 'Privacy', 'Open with', 'Permissions', 'Help & about'];
          final ys = <double>[];
          for (final label in expected) {
            // On Android the File access row repeats the section name in its own title.
            final found = find.text(label);
            expect(found, label == 'File access' && platform == TargetPlatform.android ? findsNWidgets(2) : findsOneWidget,
                reason: label);
            ys.add(tester.getTopLeft(found.first).dy);
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
            ? ['File access', 'Reading', 'Appearance', 'Privacy & data', 'About']
            : ['File handling', 'Reading', 'Appearance', 'Privacy & data', 'Keyboard shortcuts', 'About'];
        final hidden = isMobile
            ? ['File handling', 'Keyboard shortcuts', 'Files & storage', 'Data', 'Privacy', 'Open with']
            : ['File access', 'Files & storage', 'Data', 'Privacy', 'Open with'];
        final list = find.byKey(const ValueKey('settings-section-list'));
        expect(list, findsOneWidget);
        for (final title in expected) {
          expect(find.descendant(of: list, matching: find.text(title)), findsOneWidget, reason: title);
        }
        for (final title in hidden) {
          expect(find.descendant(of: list, matching: find.text(title)), findsNothing, reason: title);
        }
        // The first section of the platform is on the right.
        expect(find.byKey(ValueKey('settings-pane-${isMobile ? 'fileAccess' : 'fileHandling'}')), findsOneWidget);
      });
    }
  });

  group('permissions', () {
    testWidgets('Android allowed: one compact row, no note, no help, and the row opens the All files access page', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360);
      expect(find.text('Allowed'), findsOneWidget);
      expect(find.byKey(const ValueKey('file-access-detail')), findsNothing, reason: 'no supporting line');
      expect(find.text('OpenReader can find your documents'), findsNothing);
      expect(find.text('Manage file access'), findsNothing, reason: 'no third line');
      expect(find.textContaining('limited mode'), findsNothing);
      expect(find.byType(HowToAllowAccess), findsNothing);
      expect(find.text('Allow file access'), findsNothing);
      final handle = tester.ensureSemantics();
      final fileAccessRow = find.ancestor(of: find.byKey(const ValueKey('file-access-status')), matching: find.byType(InkWell)).first;
      expect(tester.getSemantics(fileAccessRow).label, contains('Manage file access'));
      handle.dispose();
      await tester.tap(fileAccessRow);
      await tester.pump();
      expect(storage.allFiles, 1);
      expect(storage.opened, 0);
      expect(storage.requests, 0);
      await drainWatch(tester);
    });

    testWidgets('Android not allowed: chip, filled button, one-line note and the how-to link', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
      expect(find.text('Not allowed'), findsOneWidget);
      expect(find.textContaining('(limited mode)'), findsNothing);
      expect(find.text(PermissionsSection.limitedModeNote), findsOneWidget);
      expect(find.byType(HowToAllowAccess), findsOneWidget);
      expect(find.byKey(const ValueKey('allow-file-access')), findsOneWidget);
      await tester.tap(find.text('Allow file access'));
      await tester.pump();
      expect(storage.requests, 1);
      expect(storage.opened, 0);
      await drainWatch(tester);
    });

    testWidgets('Android blocked: chip, then explain and open the page', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.blocked);
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text(PermissionsSection.limitedModeNote), findsOneWidget);
      await tester.tap(find.text('Allow file access'));
      await tester.pumpAndSettle();
      expect(storage.allFiles, 0, reason: 'explained first');
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      expect(storage.allFiles, 1);
      expect(storage.opened, 0);
      await drainWatch(tester);
    });

    testWidgets('the limited-mode note follows the state', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360);
      expect(find.textContaining('limited mode'), findsNothing);
      c.storageState.value = StorageAccessState.notAllowed;
      await tester.pump();
      expect(find.text(PermissionsSection.limitedModeNote), findsOneWidget);
      c.storageState.value = StorageAccessState.allowed;
      await tester.pump();
      expect(find.textContaining('limited mode'), findsNothing);
    });

    for (final scale in [1.0, 2.0]) {
      for (final access in [StorageAccessState.allowed, StorageAccessState.notAllowed, StorageAccessState.blocked]) {
        testWidgets('360 px, text x$scale, $access: no overflow, chip on the title line, 48 dp targets', (tester) async {
          await pump(tester, platform: TargetPlatform.android, width: 360, access: access, textScale: scale);
          expect(tester.takeException(), isNull);
          final chip = find.byKey(const ValueKey('file-access-status'));
          final chipBox = tester.getRect(find.ancestor(of: chip, matching: find.byType(SettingsStatusChip)));
          final titleBox = tester.getRect(find.descendant(
              of: find.ancestor(of: chip, matching: find.byType(InkWell)).first, matching: find.text('File access')));
          // The chip keeps one line of text (the test font is much wider than a real one, so on a
          // real phone it also shares the title line at x1.0; here it may drop below as a whole).
          if (scale == 1) expect(tester.getSize(chip).height, lessThan(28), reason: 'single line, not a wrapped column');
          expect(chipBox.right, lessThanOrEqualTo(360));
          if (access != StorageAccessState.allowed) {
            final supporting = tester.getRect(find.byKey(const ValueKey('file-access-detail')));
            expect(supporting.left, titleBox.left, reason: 'supporting text starts under the title, on the full row width');
            expect(supporting.right, greaterThanOrEqualTo(chipBox.right));
          } else {
            expect(find.byKey(const ValueKey('file-access-detail')), findsNothing);
          }
          final row = find.ancestor(of: chip, matching: find.byType(InkWell)).first;
          expect(tester.getSize(row).height, greaterThanOrEqualTo(access == StorageAccessState.allowed ? 48 : 56));
          if (access != StorageAccessState.allowed) {
            expect(tester.getSize(find.byKey(const ValueKey('allow-file-access'))).height, greaterThanOrEqualTo(48));
            expect(tester.getSize(find.byKey(const ValueKey('how-to-allow'))).height, greaterThanOrEqualTo(48));
          }
        });
      }
    }

    testWidgets('API 30+ status never shows Blocked for the old permission: only allowed or not allowed', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
      expect(find.text('Blocked'), findsNothing);
    });

    group('re-checks after the OS page', () {
      testWidgets('resume refreshes at once, then at 0.7 s, 1.5 s and 3 s while the state is unchanged', (tester) async {
        await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
        final before = storage.stateReads;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(storage.stateReads, before + 1, reason: 'immediately');
        await tester.pump(const Duration(milliseconds: 650));
        expect(storage.stateReads, before + 1);
        await tester.pump(const Duration(milliseconds: 100));
        expect(storage.stateReads, before + 2, reason: '0.7 s');
        await tester.pump(const Duration(milliseconds: 800));
        expect(storage.stateReads, before + 3, reason: '1.5 s');
        await tester.pump(const Duration(milliseconds: 1500));
        expect(storage.stateReads, before + 4, reason: '3 s');
        await tester.pump(const Duration(seconds: 10));
        expect(storage.stateReads, before + 4, reason: 'no more');
      });

      testWidgets('a late grant shows at the next re-check and stops the rest', (tester) async {
        await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(find.text('Not allowed'), findsOneWidget);
        storage.current = StorageAccessState.allowed;
        await tester.pump(const Duration(milliseconds: 750));
        expect(find.text('Allowed'), findsOneWidget);
        final reads = storage.stateReads;
        await tester.pump(const Duration(seconds: 5));
        expect(storage.stateReads, reads, reason: 'stopped once it changed');
      });

      testWidgets('an immediate change stops the re-checks', (tester) async {
        await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
        storage.current = StorageAccessState.allowed;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
        expect(find.text('Allowed'), findsOneWidget);
        final reads = storage.stateReads;
        await tester.pump(const Duration(seconds: 5));
        expect(storage.stateReads, reads);
      });

      testWidgets('closing the controller cancels the re-checks', (tester) async {
        final c = await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
        await c.watchPermissions(c.storageState.value);
        final reads = storage.stateReads;
        c.onClose();
        await tester.pump(const Duration(seconds: 5));
        expect(storage.stateReads, reads);
      });

      testWidgets('opening the All files page from Settings watches too', (tester) async {
        final c = await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notAllowed);
        await c.openAllFilesAccess();
        final reads = storage.stateReads;
        storage.current = StorageAccessState.allowed;
        await tester.pump(const Duration(milliseconds: 750));
        expect(storage.stateReads, reads + 1);
        expect(c.storageState.value, StorageAccessState.allowed);
      });
    });

    testWidgets('Android: a status that cannot be read shows no status', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, access: StorageAccessState.notApplicable);
      for (final label in ['Allowed', 'Blocked', 'Not allowed']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('App permissions'), findsOneWidget);
    });

    testWidgets('iOS: App permissions opens the app settings and no status shows', (tester) async {
      await pump(tester, platform: TargetPlatform.iOS, width: 360);
      for (final label in ['Allowed', 'Blocked', 'Not allowed']) {
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
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      // The PDF reading mode is not on this page: the PDF reader's toolbar owns it.
      expect(find.text('PDF default view'), findsNothing);
      expect(find.text('Page by page'), findsNothing);
      await tester.tap(find.text('Night mode'));
      await tester.tap(find.byTooltip('Larger text'));
      await tester.tap(find.text('Wrap long lines'));
      await tester.tap(find.text('Restore last position'));
      await tester.pump();
      await tester.runAsync(() async {
        expect(await repo.getReaderNightMode(), isTrue);
        expect(await repo.getTextReaderFontSize(), 18);
        expect(await repo.getTextReaderLineWrap(), isFalse);
        expect(await repo.getRestoreReadingPosition(), isFalse);
      });
      expect(tester.widget<Text>(find.byKey(const ValueKey('font-size-value'))).data, '18 pt');
      expect(find.byKey(const ValueKey('font-sample')), findsNothing);
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
    testWidgets('states always-on Firebase collection, with no switches, and links the policy', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.textContaining('Google Firebase'), findsOneWidget);
      expect(find.textContaining('never uploaded'), findsOneWidget);
      expect(find.textContaining('are sent to Google Firebase'), findsOneWidget);
      expect(find.text('Send crash reports'), findsNothing);
      expect(find.text('Share usage analytics'), findsNothing);
      expect(find.text('Privacy policy'), findsOneWidget);
      // Firebase uses a random installation identifier: the statement must not claim anonymity.
      expect(find.textContaining('nonymous'), findsNothing);
      expect(find.textContaining('random installation ID'), findsOneWidget);
    });
  });

  group('privacy policy link (ST-06, Q2)', () {
    for (final platform in [...mobile, ...desktop]) {
      testWidgets('$platform: Privacy shows the link with the external-link icon, above the toggle, statement as the footnote', (tester) async {
        await pump(tester, platform: platform, width: 360, height: 8000);
        final row = find.widgetWithText(SettingsActionRow, 'Privacy policy');
        expect(row, findsOneWidget);
        expect(find.descendant(of: row, matching: find.byIcon(Icons.open_in_new_rounded)), findsOneWidget);
        final y = tester.getTopLeft(find.text('Privacy policy')).dy;
        expect(y, lessThan(tester.getTopLeft(find.text('Hide thumbnails')).dy));
        expect(y, lessThan(tester.getTopLeft(find.textContaining('never uploaded')).dy), reason: 'footnote is under the card');
      });
    }

    testWidgets('opens the exact policy URL', (tester) async {
      final opened = <String>[];
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000, openUrl: (url) async {
        opened.add(url);
        return true;
      });
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      expect(opened, ['https://macdipu.github.io/OpenReader/privacy.html']);
      expect(find.text('Could not open the privacy policy.'), findsNothing);
    });

    testWidgets('a policy page that cannot be opened shows an error, no crash', (tester) async {
      await pump(tester, platform: TargetPlatform.linux, width: 360, height: 8000, openUrl: (_) async => false);
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Could not open the privacy policy.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await drain(tester);
    });

    testWidgets('a launcher that throws also shows the error', (tester) async {
      await pump(tester, platform: TargetPlatform.iOS, width: 360, height: 8000,
          openUrl: (_) async => throw Exception('no browser'));
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Could not open the privacy policy.'), findsOneWidget);
      await drain(tester);
    });
  });

  group('storage access', () {
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
      expect(storage.allFiles, 1);
      expect(storage.opened, 0);

      storage.current = StorageAccessState.blocked;
      c.storageState.value = StorageAccessState.blocked;
      final pending = c.fixStorageAccess();
      await tester.pumpAndSettle();
      expect(storage.allFiles, 1, reason: 'explains first');
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      await pending;
      expect(storage.allFiles, 2);
      expect(storage.opened, 0);
      expect(storage.requests, 1);

      c.storageState.value = null;
      await c.fixStorageAccess();
      expect(storage.requests, 1);
      expect(storage.opened, 0);
    });

  });

  group('two-pane keyboard', () {
    testWidgets('arrow keys move between sections, Tab moves into the controls', (tester) async {
      await pump(tester, platform: TargetPlatform.windows, width: 1200, height: 1400);
      final list = find.byKey(const ValueKey('settings-section-list'));
      await tester.tap(find.descendant(of: list, matching: find.text('File handling')));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-pane-shortcuts')), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Ctrl+,'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-pane-privacyData')), findsOneWidget);
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

  group('Privacy & data section (CR-SETTINGS-UX, ST-07; ST-11/ST-12 removed 2026-11-21)', () {
    const removed = ['cache', 'limit', 'retention', 'Clear render cache', 'Forever', '30 days', 'No limit', 'Keep reading history'];

    testWidgets('has Clear all history and Reset all settings in the one card, and nothing about cache, limit or retention',
        (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.text('Data'), findsNothing);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('Clear all history'), findsOneWidget);
      expect(find.text('Removes your recent files. Your documents are not deleted.'), findsOneWidget);
      expect(find.text('Reset all settings'), findsOneWidget);
      expect(find.text('Puts every setting back to its default.'), findsOneWidget);
      for (final word in removed) {
        expect(find.textContaining(word, findRichText: true), findsNothing, reason: word);
        expect(find.textContaining(word.toLowerCase()), findsNothing, reason: word);
      }
      expect(find.byType(SegmentedButton<int?>), findsNothing);
    });

    testWidgets('Clear all history: Cancel does nothing; confirm clears and shows the success message', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      await tester.tap(find.text('Clear all history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(recents.cleared, 0);
      expect(find.text(SettingsController.historyClearedMessage), findsNothing);

      await tester.tap(find.text('Clear all history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(recents.cleared, 1);
      expect(find.text(SettingsController.historyClearedMessage), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Reset all settings: Cancel does nothing; confirm resets and shows the success message', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, prefs: {
        'app_settings:pdf_night_mode': true,
      });
      await tester.pump();
      expect(c.nightMode.value, isTrue);
      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      expect(find.text('Reset all settings?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => expect(await repo.getReaderNightMode(), isTrue));
      expect(find.text(SettingsController.resetMessage), findsNothing);

      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await settle(tester, () => find.text(SettingsController.resetMessage).evaluate().isNotEmpty);
      expect(find.text(SettingsController.resetMessage), findsOneWidget);
      expect(c.nightMode.value, isFalse);
      await drain(tester);
    });

    for (final platform in [...mobile, ...desktop]) {
      testWidgets('$platform: Privacy & data follows Appearance in the platform order', (tester) async {
        final order = (() { debugDefaultTargetPlatformOverride = platform; addTearDown(() => debugDefaultTargetPlatformOverride = null); return settingsSectionsForPlatform(); })().map((e) => e.title).toList();
        expect(order, contains('Privacy & data'));
        expect(order.indexOf('Privacy & data'), order.indexOf('Appearance') + 1);
        for (final gone in ['Files & storage', 'Data', 'Privacy', 'Open with']) {
          expect(order, isNot(contains(gone)));
        }
      });
    }

    for (final platform in desktop) {
      testWidgets('$platform: the Privacy & data pane has the two actions in the two-pane layout', (tester) async {
        await pump(tester, platform: platform, width: 1200, height: 1400);
        final list = find.byKey(const ValueKey('settings-section-list'));
        await tester.tap(find.descendant(of: list, matching: find.text('Privacy & data')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings-pane-privacyData')), findsOneWidget);
        expect(find.text('Clear all history'), findsOneWidget);
        expect(find.text('Reset all settings'), findsOneWidget);
        expect(find.text('Clear render cache'), findsNothing);
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('360 px, text x$scale: no overflow, both rows are 48 dp or taller', (tester) async {
        await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, textScale: scale);
        expect(tester.takeException(), isNull);
        for (final title in ['Clear all history', 'Reset all settings']) {
          final row = find.ancestor(of: find.text(title), matching: find.byType(SettingsActionRow));
          expect(tester.getSize(row.first).height, greaterThanOrEqualTo(48), reason: title);
        }
      });
    }
  });

  group('help and about', () {
    testWidgets('has Send feedback, Rate (Android), Share and welcome screens', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.text('Share app'), findsOneWidget);
      expect(find.text('Show welcome screens again'), findsOneWidget);
      // Reset all settings lives in Privacy & data, above the About label, not below it.
      expect(tester.getTopLeft(find.text('Reset all settings')).dy, lessThan(tester.getTopLeft(find.text('About')).dy));
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
    testWidgets('hidden when allowed', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.text('How to allow it yourself'), findsNothing);
    });

    testWidgets('opens a bottom sheet on a phone, not inline', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, access: StorageAccessState.notAllowed);
      expect(find.text('Or find it yourself'), findsNothing);
      await tester.tap(find.text('How to allow it yourself'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Or find it yourself'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Open All files access'), findsOneWidget);
      expect(find.text('Open app settings'), findsNothing);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(FilledButton)), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextButton)), findsNothing);
    });

    testWidgets('shows numbered steps for the phone brand only, fits 360 px at text scale 2 (A-14/A-15)', (tester) async {
      await pump(tester,
          platform: TargetPlatform.android, width: 360, height: 640, access: StorageAccessState.notAllowed, textScale: 2.0);
      storage.brand = DeviceBrand.coloros;
      await tester.ensureVisible(find.text('How to allow it yourself'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How to allow it yourself'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('Allow management of all files'), findsOneWidget);
      expect(find.text('Settings > Apps > App management > OpenReader > Permissions > Files and media'), findsOneWidget);
      expect(find.textContaining('Special access'), findsNothing);
      expect(find.textContaining('Manage apps'), findsNothing);
      expect(find.text('Or find it yourself'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('safe area: the last button clears a 48 px navigation bar at 360 px, text scale $scale', (tester) async {
        await pump(tester,
            platform: TargetPlatform.android, width: 360, height: 800, access: StorageAccessState.notAllowed, textScale: scale);
        tester.view.viewPadding = const FakeViewPadding(bottom: 48);
        addTearDown(tester.view.resetViewPadding);
        await tester.pump();
        await tester.ensureVisible(find.text('How to allow it yourself'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('How to allow it yourself'), warnIfMissed: false);
        await tester.pumpAndSettle();
        final scrollable = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
        await tester.scrollUntilVisible(find.text('Open All files access'), 100, scrollable: scrollable);
        await tester.drag(scrollable, const Offset(0, -2000));
        await tester.pumpAndSettle();
        final bottom = tester.getBottomLeft(find.widgetWithText(FilledButton, 'Open All files access')).dy;
        expect(bottom, lessThanOrEqualTo(800 - 48));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Android 10 or older: one step, no brand lines, no All files button', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 800, access: StorageAccessState.notAllowed);
      storage.sdk = 29;
      storage.brand = DeviceBrand.samsung;
      await tester.tap(find.text('How to allow it yourself'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Tap Allow on the Storage permission prompt.', findRichText: true), findsOneWidget);
      expect(find.textContaining('Special access'), findsNothing);
      expect(find.text('Open All files access'), findsNothing);
      expect(find.text('Open app settings'), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(FilledButton)), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextButton)), findsNothing);
    });

    testWidgets('opens a dialog on a wide window', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 1000, height: 5000, access: StorageAccessState.notAllowed);
      await tester.tap(find.text('How to allow it yourself'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Or find it yourself'), findsOneWidget);
    });

    testWidgets('the sheet button opens the All files page (sdk 34) or the app settings (sdk 29), and closes it', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000, access: StorageAccessState.blocked);
      await tester.tap(find.text('How to allow it yourself'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open All files access'));
      await tester.pumpAndSettle();
      expect(storage.allFiles, 1);
      expect(storage.opened, 0);
      expect(find.byType(BottomSheet), findsNothing);
      storage.sdk = 29;
      await tester.tap(find.text('How to allow it yourself'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open app settings'));
      await tester.pumpAndSettle();
      expect(storage.opened, 1);
      expect(storage.allFiles, 1);
      await drainWatch(tester);
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

    test('Android: opens the All files access page through the device channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var opened = 0;
      final svc = StorageAccessService.test(() async => 34, allFilesOpener: () async => ++opened > 0);
      expect(await svc.openAllFilesAccessSettings(), isTrue);
      expect(opened, 1);
      expect(calls, isEmpty);
    });

    test('Android 11+: a false answer or an error falls back to the app settings', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      for (final opener in <Future<bool> Function()>[() async => false, () async => throw PlatformException(code: 'x')]) {
        calls.clear();
        final svc = StorageAccessService.test(() async => 30, allFilesOpener: opener);
        expect(await svc.openAllFilesAccessSettings(), isTrue);
        expect(calls, ['openAppSettings']);
      }
    });

    test('Android 10: the app settings, the channel is not used', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var opened = 0;
      final svc = StorageAccessService.test(() async => 29, allFilesOpener: () async => ++opened > 0);
      expect(await svc.openAllFilesAccessSettings(), isTrue);
      expect(opened, 0);
      expect(calls, ['openAppSettings']);
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

  group('keep screen awake (ST-16)', () {
    tearDown(() => ReaderWakelock.reset());

    Finder switchOf(String title) =>
        find.descendant(of: find.widgetWithText(SettingsSwitchRow, title), matching: find.byType(Switch));

    for (final platform in [...mobile, ...desktop]) {
      testWidgets('$platform: Reading has the switch, off by default', (tester) async {
        final c = await pump(tester, platform: platform, width: 360, height: 8000);
        expect(c.keepScreenAwake.value, isFalse);
        expect(tester.widget<Switch>(switchOf('Keep screen awake')).value, isFalse);
        expect(find.text('While a document is open'), findsOneWidget);
      });
    }

    testWidgets('it saves, reaches the reader wakelock, and reset clears it', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      await tester.tap(find.text('Keep screen awake'));
      await tester.pump();
      expect(c.keepScreenAwake.value, isTrue);
      expect(ReaderWakelock.keepAwake.value, isTrue);
      await tester.runAsync(() async => expect(await repo.getKeepScreenAwake(), isTrue));
      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(c.keepScreenAwake.value, isFalse);
      expect(ReaderWakelock.keepAwake.value, isFalse);
      await drain(tester);
    });

    testWidgets('a saved choice is applied when Settings loads', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.windows, width: 360, height: 8000, prefs: {
        'app_settings:keep_screen_awake': true,
      });
      await tester.pump();
      expect(c.keepScreenAwake.value, isTrue);
      expect(ReaderWakelock.keepAwake.value, isTrue);
    });
  });

  group('dynamic colour (ST-20)', () {
    final schemes = DynamicColorPreferences.fromSeed(const Color(0xFF2E7D32));
    tearDown(() {
      DynamicColorPreferences.enabled.value = false;
      DynamicColorPreferences.light.value = null;
      DynamicColorPreferences.dark.value = null;
    });

    Finder switchOf(String title) =>
        find.descendant(of: find.widgetWithText(SettingsSwitchRow, title), matching: find.byType(Switch));

    for (final platform in [...mobile, ...desktop]) {
      testWidgets('$platform: no switch when the system offers no palette', (tester) async {
        await pump(tester, platform: platform, width: 360, height: 8000);
        expect(find.text('Use wallpaper colours'), findsNothing);
        expect(find.text('Use accent colour'), findsNothing);
        expect(find.text('Theme'), findsOneWidget);
      });
    }

    testWidgets('Android with a palette: "Use wallpaper colours", off by default, saved and live', (tester) async {
      DynamicColorPreferences.light.value = schemes.light;
      DynamicColorPreferences.dark.value = schemes.dark;
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      expect(find.text('Use wallpaper colours'), findsOneWidget);
      expect(tester.widget<Switch>(switchOf('Use wallpaper colours')).value, isFalse);
      expect(DynamicColorPreferences.activeLight, isNull);
      await tester.tap(find.text('Use wallpaper colours'));
      await tester.pump();
      expect(c.useDynamicColor.value, isTrue);
      expect(DynamicColorPreferences.activeLight, same(schemes.light));
      expect(DynamicColorPreferences.activeDark, same(schemes.dark));
      await tester.runAsync(() async => expect(await repo.getUseDynamicColor(), isTrue));
      await tester.tap(find.text('Use wallpaper colours'));
      await tester.pump();
      expect(DynamicColorPreferences.activeLight, isNull);
      await tester.runAsync(() async => expect(await repo.getUseDynamicColor(), isFalse));
    });

    testWidgets('desktop with an accent colour: "Use accent colour"', (tester) async {
      DynamicColorPreferences.light.value = schemes.light;
      DynamicColorPreferences.dark.value = schemes.dark;
      await pump(tester, platform: TargetPlatform.macOS, width: 360, height: 8000);
      expect(find.text('Use accent colour'), findsOneWidget);
      expect(find.text('Use wallpaper colours'), findsNothing);
    });

    testWidgets('a saved choice loads; reset turns it off', (tester) async {
      DynamicColorPreferences.light.value = schemes.light;
      DynamicColorPreferences.dark.value = schemes.dark;
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000, prefs: {
        'app_settings:use_dynamic_color': true,
      });
      await tester.pump();
      expect(c.useDynamicColor.value, isTrue);
      expect(DynamicColorPreferences.enabled.value, isTrue);
      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(c.useDynamicColor.value, isFalse);
      expect(DynamicColorPreferences.enabled.value, isFalse);
      await drain(tester);
    });

    test('load reads the saved choice and the injected palette; a failing source leaves none', () async {
      SharedPreferences.setMockInitialValues({'app_settings:use_dynamic_color': true});
      await DynamicColorPreferences.load(repository: repo, source: () async => schemes);
      expect(DynamicColorPreferences.enabled.value, isTrue);
      expect(DynamicColorPreferences.available, isTrue);
      await DynamicColorPreferences.load(repository: repo, source: () async => throw Exception('no plugin'));
      expect(DynamicColorPreferences.available, isFalse);
      expect(DynamicColorPreferences.activeLight, isNull);
    });

    test('the theme takes the dynamic accent when given, and is unchanged without one', () {
      for (final (brand, dynamic, scheme) in [
        (AppTheme.lightTheme, AppTheme.light(schemes.light), schemes.light),
        (AppTheme.darkTheme, AppTheme.dark(schemes.dark), schemes.dark),
      ]) {
        expect(dynamic.colorScheme.secondary, scheme.primary);
        expect(dynamic.colorScheme.onSecondary, scheme.onPrimary);
        expect(dynamic.colorScheme.secondaryContainer, scheme.primaryContainer);
        expect(dynamic.colorScheme.onSecondaryContainer, scheme.onPrimaryContainer);
        // Surfaces, ink, error and the success tertiary stay the brand's.
        expect(dynamic.colorScheme.surface, brand.colorScheme.surface);
        expect(dynamic.colorScheme.onSurface, brand.colorScheme.onSurface);
        expect(dynamic.colorScheme.surfaceContainerLowest, brand.colorScheme.surfaceContainerLowest);
        expect(dynamic.colorScheme.error, brand.colorScheme.error);
        expect(dynamic.colorScheme.tertiary, brand.colorScheme.tertiary);
        expect(dynamic.scaffoldBackgroundColor, brand.scaffoldBackgroundColor);
      }
      expect(AppTheme.light().colorScheme, AppTheme.lightTheme.colorScheme);
      expect(AppTheme.dark().colorScheme, AppTheme.darkTheme.colorScheme);
      expect(AppTheme.light().switchTheme.thumbColor?.resolve({WidgetState.selected}),
          AppTheme.lightTheme.colorScheme.secondary);
    });

    test('dynamic accents from Android palettes and accent colours keep WCAG AA', () {
      final seeds = [const Color(0xFF2E7D32), const Color(0xFFD81B60), const Color(0xFFFFC107), const Color(0xFF0051D5)];
      for (final seed in seeds) {
        final fromSeed = DynamicColorPreferences.fromSeed(seed);
        final fromTones = DynamicColorPreferences.fromPrimaryTones((tone) => _tone(seed, tone));
        for (final s in [fromSeed, fromTones]) {
          for (final theme in [AppTheme.light(s.light), AppTheme.dark(s.dark)]) {
            final cs = theme.colorScheme;
            final reason = '${theme.brightness.name} $seed';
            expect(_contrast(cs.secondary, cs.surfaceContainerLowest), greaterThanOrEqualTo(4.5), reason: reason);
            expect(_contrast(cs.onSecondary, cs.secondary), greaterThanOrEqualTo(4.5), reason: reason);
            expect(_contrast(cs.onSecondaryContainer, cs.secondaryContainer), greaterThanOrEqualTo(4.5), reason: reason);
            expect(_contrast(cs.secondary, cs.secondaryContainer), greaterThanOrEqualTo(3), reason: reason);
          }
        }
      }
    });

    testWidgets('a theme built like the app\'s rebuilds live when the switch changes', (tester) async {
      DynamicColorPreferences.light.value = schemes.light;
      DynamicColorPreferences.dark.value = schemes.dark;
      late ThemeData seen;
      await tester.pumpWidget(Obx(() => MaterialApp(
            theme: AppTheme.light(DynamicColorPreferences.activeLight),
            darkTheme: AppTheme.dark(DynamicColorPreferences.activeDark),
            home: Builder(builder: (context) {
              seen = Theme.of(context);
              return const SizedBox();
            }),
          )));
      expect(seen.colorScheme.secondary, AppTheme.lightTheme.colorScheme.secondary);
      DynamicColorPreferences.enabled.value = true;
      await tester.pumpAndSettle();
      expect(seen.colorScheme.secondary, schemes.light.primary);
      DynamicColorPreferences.enabled.value = false;
      await tester.pumpAndSettle();
      expect(seen.colorScheme.secondary, AppTheme.lightTheme.colorScheme.secondary);
    });
  });

  group('settings redesign 2026-11-21', () {
    Future<double> pageHeight(WidgetTester tester) async {
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      return position.maxScrollExtent + position.viewportDimension;
    }

    testWidgets('the whole mobile page (Android, access allowed, 360x800) is at most about 3.2 screens', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 800);
      final height = await pageHeight(tester);
      debugPrint('settings page height at 360x800: ${height.toStringAsFixed(0)} logical px');
      expect(height, lessThan(2600));
      expect(tester.takeException(), isNull);
    });

    for (final platform in [...mobile, ...desktop]) {
      testWidgets('$platform: section labels in order, none of the old labels', (tester) async {
        await pump(tester, platform: platform, width: 360, height: 8000);
        final labels = find.byType(SettingsSectionLabel).evaluate().map((e) => (e.widget as SettingsSectionLabel).title).toList();
        expect(
            labels,
            mobile.contains(platform)
                ? ['File access', 'Reading', 'Appearance', 'Privacy & data', 'About']
                : ['File handling', 'Reading', 'Appearance', 'Privacy & data', 'Keyboard shortcuts', 'About']);
        for (final old in ['Files & storage', 'Data', 'Open with', 'Privacy', 'Permissions', 'Help & about']) {
          expect(find.text(old), findsNothing, reason: old);
        }
      });
    }

    testWidgets('the Open with tip is a footnote of About on Android and iOS only', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      expect(find.textContaining('"Open with"'), findsOneWidget);
      expect(find.text('Open with'), findsNothing);
      await pump(tester, platform: TargetPlatform.iOS, width: 360, height: 8000);
      expect(find.textContaining('touch and hold a document'), findsOneWidget);
      await pump(tester, platform: TargetPlatform.windows, width: 360, height: 8000);
      expect(find.textContaining('Open with'), findsNothing);
      expect(find.textContaining('touch and hold'), findsNothing);
    });

    testWidgets('Text size is a stepper only: no sample sentence', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      expect(find.textContaining('quick brown fox'), findsNothing);
      expect(find.byKey(const ValueKey('font-sample')), findsNothing);
      expect(find.byTooltip('Smaller text'), findsOneWidget);
      expect(find.byTooltip('Larger text'), findsOneWidget);
    });

    testWidgets('Theme is one 3-segment control with text only', (tester) async {
      final c = await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      final control = find.byType(SegmentedButton<ThemeMode>);
      expect(control, findsOneWidget);
      expect(tester.widget<SegmentedButton<ThemeMode>>(control).segments, hasLength(3));
      for (final label in ['Light', 'Dark', 'System']) {
        expect(find.descendant(of: control, matching: find.text(label)), findsOneWidget);
      }
      expect(find.descendant(of: control, matching: find.byType(Icon)), findsNothing);
      await tester.tap(find.descendant(of: control, matching: find.text('Dark')));
      await tester.pump();
      expect(c.themeController.themeMode, ThemeMode.dark);
    });

    testWidgets('the privacy footnote is short and under the card; Reset is the error colour', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      final footnote = find.textContaining('never uploaded');
      expect(footnote, findsOneWidget);
      final text = tester.widget<Text>(footnote).data!;
      expect(text, contains('Google Firebase'));
      expect(text.length, lessThan(170));
      expect(tester.getTopLeft(footnote).dy, greaterThan(tester.getTopLeft(find.text('Reset all settings')).dy));
      final resetTitle = tester.widget<Text>(find.text('Reset all settings'));
      expect(resetTitle.style?.color, Theme.of(tester.element(find.text('Reset all settings'))).colorScheme.error);
    });

    testWidgets('the reset confirm names reading, appearance and privacy choices', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000);
      await tester.tap(find.text('Reset all settings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('reading, appearance and privacy choices'), findsOneWidget);
      expect(find.textContaining('storage'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('360 px, text x$scale: no overflow, every row is 48dp or taller (56dp with a supporting line)',
          (tester) async {
        await pump(tester, platform: TargetPlatform.android, width: 360, height: 8000, textScale: scale);
        expect(tester.takeException(), isNull);
        for (final type in [SettingsActionRow, SettingsSwitchRow]) {
          for (final element in find.byType(type).evaluate()) {
            final box = element.renderObject! as RenderBox;
            final hasSubtitle = switch (element.widget) {
              final SettingsActionRow r => r.subtitle != null,
              final SettingsSwitchRow r => r.subtitle != null,
              _ => false,
            };
            expect(box.size.height, greaterThanOrEqualTo(hasSubtitle ? 56 : 48), reason: '$type ${_texts(element)}');
          }
        }
      });
    }
  });

  group('accessibility (N4)', () {
    testWidgets('the theme segments are at least 48dp tall', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(tester.getSize(find.byType(SegmentedButton<ThemeMode>)).height, greaterThanOrEqualTo(48));
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

  group('standard UX: segmented choices', () {
    testWidgets('2-3 option choices stay segmented', (tester) async {
      await pump(tester, platform: TargetPlatform.android, width: 360, height: 5000);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.byType(SegmentedButton<bool>), findsNothing, reason: 'the PDF mode row is not on this page');
      expect(find.byType(SegmentedButton<int?>), findsNothing, reason: 'history retention was removed');
    });
  });

  group('standard UX: status is never colour only', () {
    for (final (state, label, kind) in [
      (StorageAccessState.allowed, 'Allowed', 'ok'),
      (StorageAccessState.notAllowed, 'Not allowed', 'warning'),
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
      for (final title in ['File access', 'Reading', 'Privacy & data', 'About']) {
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
      await tester.tap(find.text('Clear all history'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all reading history?'), findsOneWidget);
      final confirm = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Clear'));
      final ctx = tester.element(find.text('Clear all reading history?'));
      expect(confirm.style?.foregroundColor?.resolve({}), Theme.of(ctx).colorScheme.error);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(recents.cleared, 0);

      await tester.tap(find.text('Clear all history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(recents.cleared, 1);
      expect(find.text(SettingsController.historyClearedMessage), findsOneWidget);
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
      for (final title in ['Clear all history', 'Reset all settings', 'Show welcome screens again']) {
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
