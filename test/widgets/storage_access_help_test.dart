import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/presentation/theme/app_theme.dart';
import 'package:openreader/core/presentation/utils/storage_access_help.dart';
import 'package:openreader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:openreader/features/onboarding/presentation/onboarding_view.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';

String _text(StorageAccessHelp help) =>
    '${help.steps.map((s) => s.map((e) => e.text).join()).join('\n')}\n${help.manualPath ?? ''}';

class _Access implements StorageAccessService {
  _Access(this.brand, this.sdk);
  final DeviceBrand brand;
  final int sdk;
  @override
  Future<int?> androidSdkInt() async => sdk;
  @override
  Future<DeviceBrand> deviceBrand() async => brand;
  @override
  Future<bool> hasAccess() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DeviceBrand.fromNames', () {
    const cases = {
      'samsung': DeviceBrand.samsung,
      'oppo': DeviceBrand.coloros,
      'realme': DeviceBrand.coloros,
      'oneplus': DeviceBrand.coloros,
      'xiaomi': DeviceBrand.hyperos,
      'redmi': DeviceBrand.hyperos,
      'poco': DeviceBrand.hyperos,
      'vivo': DeviceBrand.vivo,
      'iqoo': DeviceBrand.vivo,
      'google': DeviceBrand.other,
      'motorola': DeviceBrand.other,
      'nokia': DeviceBrand.other,
    };
    cases.forEach((name, expected) {
      test('$name -> $expected',
          () => expect(DeviceBrand.fromNames(name, name), expected));
    });
    test(
        'the brand wins when the maker is a generic one; unknown and null are stock',
        () {
      expect(DeviceBrand.fromNames('unknown', 'Redmi'), DeviceBrand.hyperos);
      expect(DeviceBrand.fromNames(null, null), DeviceBrand.other);
    });
  });

  group('StorageAccessService.deviceBrand', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('caches the first answer and exposes it synchronously', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var reads = 0;
      final service =
          StorageAccessService.test(() async => 34, brandReader: () async {
        reads++;
        return DeviceBrand.samsung;
      });
      expect(service.cachedBrand, isNull);
      expect(await service.deviceBrand(), DeviceBrand.samsung);
      expect(await service.deviceBrand(), DeviceBrand.samsung);
      expect(reads, 1);
      expect(service.cachedBrand, DeviceBrand.samsung);
    });

    test('a failing read gives other and is retried next time', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var fail = true;
      final service =
          StorageAccessService.test(() async => 34, brandReader: () async {
        if (fail) throw StateError('no channel');
        return DeviceBrand.vivo;
      });
      expect(await service.deviceBrand(), DeviceBrand.other);
      expect(service.cachedBrand, isNull);
      fail = false;
      expect(await service.deviceBrand(), DeviceBrand.vivo);
    });

    test('off Android it is other without asking', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final service = StorageAccessService.test(() async => null,
          brandReader: () async => DeviceBrand.samsung);
      expect(await service.deviceBrand(), DeviceBrand.other);
    });
  });

  group('StorageAccessHelp content', () {
    const own = {
      DeviceBrand.samsung: [
        'Allow permission',
        'Settings > Apps > Special access > All files access > OpenReader'
      ],
      DeviceBrand.coloros: [
        'Allow management of all files',
        'Settings > Apps > App management > OpenReader > Permissions > Files and media',
      ],
      DeviceBrand.hyperos: [
        'Allow access to manage all files',
        'Settings > Apps > Manage apps > OpenReader > Permissions'
      ],
      DeviceBrand.vivo: [
        'Allow access to manage all files',
        'Settings > Apps & permissions > Permission management > OpenReader',
      ],
      DeviceBrand.other: [
        'Allow access to manage all files',
        'Settings > Apps > Special app access > All files access > OpenReader',
      ],
    };

    for (final brand in DeviceBrand.values) {
      for (final sdk in [29, 30, 34]) {
        test('$brand on sdk $sdk shows only its own lines', () {
          final text =
              _text(StorageAccessHelp.forDevice(brand: brand, sdk: sdk));
          if (sdk == 29) {
            expect(text, 'Tap Allow on the Storage permission prompt.\n');
            return;
          }
          for (final line in own[brand]!) {
            expect(text, contains(line));
          }
          expect(text, contains('Tap Open All files access below.'));
          expect(text, contains('Come back to OpenReader.'));
          for (final other in DeviceBrand.values.where((b) => b != brand)) {
            // A path or switch label that belongs only to another brand must be absent.
            for (final line in own[other]!) {
              if (!own[brand]!.contains(line))
                expect(text, isNot(contains(line)),
                    reason: '$other line "$line"');
            }
          }
        });
      }
    }

    test('an unreadable version counts as Android 11 or newer', () {
      expect(StorageAccessHelp.forDevice(brand: DeviceBrand.other).steps.length,
          3);
    });

    test('loadStorageAccessHelp never throws and falls back to stock',
        () async {
      final help = await loadStorageAccessHelp(_ThrowingAccess());
      expect(_text(help), contains('Special app access'));
    });
  });

  group('onboarding denied states', () {
    for (final brand in DeviceBrand.values) {
      for (final scale in [1.0, 2.0]) {
        for (final status in [
          OnboardingStatus.denied,
          OnboardingStatus.permanentlyDenied
        ]) {
          testWidgets(
              '$brand $status at 360 px, text scale $scale: own steps, no overflow',
              variant: TargetPlatformVariant.only(TargetPlatform.android),
              (tester) async {
            tester.view.physicalSize = const Size(360, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final controller =
                OnboardingController(storageAccess: _Access(brand, 34));
            Get.put(controller);
            addTearDown(Get.reset);
            controller.status.value = status;
            await tester.pumpWidget(GetMaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const OnboardingView(),
            ));
            await tester.pumpAndSettle();
            final help = StorageAccessHelp.forDevice(brand: brand, sdk: 34);
            expect(find.text(help.manualPath!), findsOneWidget);
            expect(find.text('Or find it yourself'), findsOneWidget);
            expect(find.text('1'), findsOneWidget);
            expect(find.text('3'), findsOneWidget);
            expect(
                find.textContaining(status == OnboardingStatus.denied
                    ? 'Allow Access'
                    : 'Open Settings'),
                findsWidgets);
            expect(find.text('Samsung One UI'), findsNothing);
            expect(find.textContaining('vivo:'), findsNothing);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}

class _ThrowingAccess implements StorageAccessService {
  @override
  Future<int?> androidSdkInt() async => throw StateError('x');
  @override
  Future<DeviceBrand> deviceBrand() async => throw StateError('x');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
