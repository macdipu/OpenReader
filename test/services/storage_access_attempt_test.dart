import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/presentation/utils/storage_access_flow.dart';
import 'package:openreader/services/utilities/access_recheck.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';

class _Access implements StorageAccessService {
  _Access({this.requestResult = false});
  final bool requestResult;
  bool granted = false;
  int opened = 0;

  @override
  Future<bool> requestOrOpenSettings() async => requestResult;

  @override
  Future<bool> hasAccess() async => granted;

  @override
  Future<bool> openAllFilesAccessSettings() async {
    opened++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageAccessAttempt', () {
    test('is taken once, and only when recent', () {
      final t0 = DateTime(2026, 11, 21, 12);
      StorageAccessAttempt.mark(t0);
      expect(StorageAccessAttempt.takeRecent(now: t0.add(const Duration(minutes: 1))), isTrue);
      expect(StorageAccessAttempt.takeRecent(now: t0.add(const Duration(minutes: 1))), isFalse);

      StorageAccessAttempt.mark(t0);
      expect(StorageAccessAttempt.takeRecent(now: t0.add(const Duration(minutes: 6))), isFalse);
    });

    test('nothing marked means nothing to show', () {
      StorageAccessAttempt.clear();
      expect(StorageAccessAttempt.takeRecent(), isFalse);
    });
  });

  group('waitUntilForeground', () {
    testWidgets('returns at once when the app is in front', (tester) async {
      var done = false;
      unawaited(waitUntilForeground().then((_) => done = true));
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('waits while the app is behind another screen, then continues on resume', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      var done = false;
      unawaited(waitUntilForeground().then((_) => done = true));
      await tester.pump(const Duration(seconds: 30));
      expect(done, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('gives up after the timeout', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      var done = false;
      unawaited(waitUntilForeground(timeout: const Duration(seconds: 5)).then((_) => done = true));
      await tester.pump(const Duration(seconds: 6));
      expect(done, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });

  group('requestStorageAccessFlow', () {
    testWidgets('guidance is shown after the app is back in front, not while it is behind', (tester) async {
      var guided = 0;
      final access = _Access();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final flow = requestStorageAccessFlow(
        access: access,
        recheck: AccessRecheck(delays: const [Duration(milliseconds: 100), Duration(milliseconds: 200)]),
        guide: () => guided++,
      );
      // The user lingers on another screen for longer than the whole re-check window.
      await tester.pump(const Duration(seconds: 20));
      expect(guided, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      await flow;
      expect(guided, 1);
    });

    testWidgets('a late grant shows no guidance and clears the attempt', (tester) async {
      var guided = 0;
      var granted = 0;
      final access = _Access();
      final flow = requestStorageAccessFlow(
        access: access,
        onGranted: () => granted++,
        recheck: AccessRecheck(delays: const [Duration(milliseconds: 100), Duration(milliseconds: 200)]),
        guide: () => guided++,
      );
      await tester.pump();
      access.granted = true;
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 150));
      await flow;
      expect(granted, 1);
      expect(guided, 0);
      expect(StorageAccessAttempt.takeRecent(), isFalse);
    });

    testWidgets('an immediate grant shows no guidance', (tester) async {
      var guided = 0;
      var granted = 0;
      await requestStorageAccessFlow(
        access: _Access(requestResult: true),
        onGranted: () => granted++,
        guide: () => guided++,
      );
      expect(granted, 1);
      expect(guided, 0);
    });
  });
}
