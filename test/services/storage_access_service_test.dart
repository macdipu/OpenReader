import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android file access by SDK level: API 30+ needs All files access only and never shows the legacy
/// "photos and media" dialog; API 29 and below keep the runtime storage permission.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final storage = Permission.storage.value;
  final manage = Permission.manageExternalStorage.value;

  const denied = 0, granted = 1, permanentlyDenied = 4;

  late Map<int, int> statuses;
  late Map<int, int> onRequest;
  late List<String> calls;
  late List<int> requested;

  setUp(() {
    statuses = {storage: denied, manage: denied};
    onRequest = {};
    calls = [];
    requested = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'checkPermissionStatus':
          return statuses[call.arguments as int] ?? denied;
        case 'requestPermissions':
          final ids = (call.arguments as List).cast<int>();
          requested.addAll(ids);
          return {
            for (final id in ids) id: statuses[id] = onRequest[id] ?? statuses[id] ?? denied,
          };
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  StorageAccessService at(int? sdk) => StorageAccessService.test(() async => sdk);

  group('API 30 and 33: All files access only', () {
    for (final sdk in [30, 33, null]) {
      test('sdk $sdk: the old storage permission does not count as access', () async {
        statuses[storage] = granted;
        final svc = at(sdk);
        expect(await svc.hasAccess(), isFalse);
        expect(await svc.state(), StorageAccessState.notAllowed);
      });

      test('sdk $sdk: All files access granted is allowed', () async {
        statuses[manage] = granted;
        expect(await at(sdk).state(), StorageAccessState.allowed);
      });

      test('sdk $sdk: a permanently denied old permission never reads as blocked', () async {
        statuses[storage] = permanentlyDenied;
        statuses[manage] = permanentlyDenied;
        final svc = at(sdk);
        expect(await svc.isPermanentlyDenied(), isFalse);
        expect(await svc.state(), StorageAccessState.notAllowed);
      });

      test('sdk $sdk: asking opens All files access and never requests the legacy permission', () async {
        final svc = at(sdk);
        expect(await svc.requestOrOpenSettings(), isFalse);
        expect(requested, [manage]);
        expect(requested, isNot(contains(storage)));
        expect(await svc.requestAccess(), isFalse);
        expect(requested, [manage, manage]);
      });

      test('sdk $sdk: a grant made on the page is reported', () async {
        onRequest[manage] = granted;
        expect(await at(sdk).requestOrOpenSettings(), isTrue);
        expect(await at(sdk).requestAccess(), isTrue);
      });

      test('sdk $sdk: already allowed asks for nothing', () async {
        statuses[manage] = granted;
        expect(await at(sdk).requestOrOpenSettings(), isTrue);
        expect(requested, isEmpty);
      });
    }
  });

  group('API 29: the runtime storage permission', () {
    test('storage granted is allowed', () async {
      statuses[storage] = granted;
      expect(await at(29).state(), StorageAccessState.allowed);
    });

    test('storage denied is not allowed; permanently denied is blocked', () async {
      expect(await at(29).state(), StorageAccessState.notAllowed);
      statuses[storage] = permanentlyDenied;
      expect(await at(29).state(), StorageAccessState.blocked);
    });

    test('asking requests the storage permission', () async {
      onRequest[storage] = granted;
      expect(await at(29).requestOrOpenSettings(), isTrue);
      expect(requested, [storage]);
    });

    test('permanently denied: asking falls back to the app settings', () async {
      statuses[storage] = permanentlyDenied;
      onRequest[storage] = permanentlyDenied;
      expect(await at(29).requestOrOpenSettings(), isFalse);
      expect(calls, contains('openAppSettings'));
    });
  });

  group('SDK level', () {
    test('is read once and cached', () async {
      var reads = 0;
      final svc = StorageAccessService.test(() async {
        reads++;
        return 33;
      });
      expect(await svc.androidSdkInt(), 33);
      expect(await svc.androidSdkInt(), 33);
      expect(reads, 1);
    });

    test('an unreadable level is not cached and counts as API 30+', () async {
      final level = <int?>[null, 29];
      final svc = StorageAccessService.test(() async => level.removeAt(0));
      statuses[storage] = granted;
      expect(await svc.hasAccess(), isFalse, reason: 'unknown behaves as API 30+');
      expect(await svc.hasAccess(), isTrue, reason: 'read again, now API 29');
    });

    test('a failing reader is treated as unreadable', () async {
      final svc = StorageAccessService.test(() async => throw PlatformException(code: 'x'));
      expect(await svc.androidSdkInt(), isNull);
    });

    test('the default reader asks the device channel and survives a missing handler', () async {
      expect(await StorageAccessService.instance.androidSdkInt(), isNull);
    });

    test('off Android there is nothing to grant', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final svc = at(33);
      expect(await svc.hasAccess(), isTrue);
      expect(await svc.isPermanentlyDenied(), isFalse);
      expect(await svc.state(), StorageAccessState.notApplicable);
    });
  });
}
