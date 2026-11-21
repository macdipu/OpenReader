import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/presentation/utils/storage_access_flow.dart';
import 'package:openreader/core/presentation/widgets/storage_privacy_note.dart';
import 'package:openreader/services/utilities/access_recheck.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';

class _Access implements StorageAccessService {
  bool granted = false;
  bool grantOnRequest = false;
  int hasAccessCalls = 0;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<bool> hasAccess() async {
    hasAccessCalls++;
    return granted;
  }

  @override
  Future<bool> requestOrOpenSettings() async {
    requests++;
    if (grantOnRequest) granted = true;
    return granted;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AccessRecheck', () {
    testWidgets('checks now, then at 0.7 s, 1.5 s and 3 s', (tester) async {
      var checks = 0;
      final recheck = AccessRecheck();
      await recheck.run(check: () async => checks++, changed: () => false);
      expect(checks, 1);
      await tester.pump(const Duration(milliseconds: 699));
      expect(checks, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(checks, 2);
      await tester.pump(const Duration(milliseconds: 800));
      expect(checks, 3);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(checks, 4);
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 4, reason: 'no more after the last delay');
      expect(recheck.isActive, isFalse);
    });

    testWidgets('stops once the state changes', (tester) async {
      var checks = 0;
      var changed = false;
      await AccessRecheck().run(
        check: () async {
          checks++;
          if (checks == 2) changed = true;
        },
        changed: () => changed,
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(checks, 2);
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 2);
    });

    testWidgets('an immediate change schedules nothing', (tester) async {
      var checks = 0;
      final recheck = AccessRecheck();
      await recheck.run(check: () async => checks++, changed: () => true);
      expect(recheck.isActive, isFalse);
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 1);
    });

    testWidgets('stops when the owner is closed', (tester) async {
      var checks = 0;
      var closed = false;
      await AccessRecheck().run(check: () async => checks++, changed: () => false, isClosed: () => closed);
      closed = true;
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 1);
    });

    testWidgets('a new run replaces the waiting checks; cancel drops them', (tester) async {
      var checks = 0;
      final recheck = AccessRecheck(delays: const [Duration(seconds: 1)]);
      await recheck.run(check: () async => checks++, changed: () => false);
      await recheck.run(check: () async => checks++, changed: () => false);
      await tester.pump(const Duration(seconds: 2));
      expect(checks, 3, reason: 'two immediate checks and one delayed');
      await recheck.run(check: () async => checks++, changed: () => false);
      recheck.cancel();
      await tester.pump(const Duration(seconds: 2));
      expect(checks, 4);
    });

    testWidgets('onSettled runs once, only when nothing changed', (tester) async {
      var settled = 0;
      final recheck = AccessRecheck(delays: const [Duration(milliseconds: 100), Duration(milliseconds: 200)]);
      await recheck.run(check: () async {}, changed: () => false, onSettled: () => settled++);
      await tester.pump(const Duration(milliseconds: 150));
      expect(settled, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(settled, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(settled, 1);

      var changed = false;
      await recheck.run(check: () async => changed = true, changed: () => changed, onSettled: () => settled++);
      await tester.pump(const Duration(seconds: 1));
      expect(settled, 1);
    });
  });

  group('requestStorageAccessFlow', () {
    testWidgets('a grant on the first answer needs no re-check and no guidance', (tester) async {
      final access = _Access()..grantOnRequest = true;
      var granted = 0;
      var guided = 0;
      await requestStorageAccessFlow(access: access, onGranted: () => granted++, guide: () => guided++);
      await tester.pump(const Duration(seconds: 10));
      expect(granted, 1);
      expect(guided, 0);
      expect(access.hasAccessCalls, 0);
    });

    testWidgets('a late grant is picked up by the re-check window', (tester) async {
      final access = _Access();
      var granted = 0;
      var guided = 0;
      await requestStorageAccessFlow(access: access, onGranted: () => granted++, guide: () => guided++);
      expect(granted, 0);
      access.granted = true;
      await tester.pump(const Duration(milliseconds: 700));
      expect(granted, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(granted, 1, reason: 'granted once');
      expect(guided, 0);
    });

    testWidgets('no access after the window shows the guidance once', (tester) async {
      final access = _Access();
      var guided = 0;
      await requestStorageAccessFlow(access: access, guide: () => guided++);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(guided, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(guided, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(guided, 1);
    });

    testWidgets('a closed owner gets no guidance', (tester) async {
      var guided = 0;
      await requestStorageAccessFlow(access: _Access(), isClosed: () => true, guide: () => guided++);
      await tester.pump(const Duration(seconds: 10));
      expect(guided, 0);
    });

    testWidgets('the default guidance is a snackbar with a Settings action', (tester) async {
      final access = _Access();
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
      await requestStorageAccessFlow(access: access);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(storageAccessGuidance), findsOneWidget);
      expect(find.textContaining('Allow management of all files'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(access.settingsOpened, 1);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('StoragePrivacyNote (A-06)', () {
    testWidgets('states the purpose and never-uploaded, with a Privacy policy link', (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StoragePrivacyNote(onOpenPolicy: () async => opened++))));
      expect(find.textContaining('find and open your documents'), findsOneWidget);
      expect(find.textContaining('never uploaded or shared'), findsOneWidget);
      await tester.tap(find.text('Privacy policy'));
      expect(opened, 1);
    });

    test('the policy address is the published one', () {
      expect(privacyPolicyUrl, 'https://macdipu.github.io/OpenReader/privacy.html');
    });
  });
}
