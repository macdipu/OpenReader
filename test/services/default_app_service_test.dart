import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/services/platform_integration/default_app_service.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('parseXdgDefault', () {
    test('default', () => expect(DefaultAppService.parseXdgDefault('openreader.desktop\n'), DefaultStatus.isDefault));
    test('other app', () => expect(DefaultAppService.parseXdgDefault('org.gnome.Evince.desktop\n'), DefaultStatus.otherApp));
    test('empty', () => expect(DefaultAppService.parseXdgDefault(''), DefaultStatus.unknown));
    test('garbage', () => expect(DefaultAppService.parseXdgDefault('xdg-mime: command failed\nfoo'), DefaultStatus.unknown));
  });

  group('parseWindowsProgId', () {
    const hdr = r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\UserChoice';
    DefaultStatus parse(String s) => DefaultAppService.parseWindowsProgId(s, appProgId: 'OpenReader.pdf');
    test('default', () => expect(parse('\r\n$hdr\r\n    ProgId    REG_SZ    OpenReader.pdf\r\n\r\n'), DefaultStatus.isDefault));
    test('other app', () => expect(parse('$hdr\r\n    ProgId    REG_SZ    AcroExch.Document.DC\r\n'), DefaultStatus.otherApp));
    test('empty', () => expect(parse(''), DefaultStatus.unknown));
    test('garbage', () => expect(parse('ERROR: Access is denied.'), DefaultStatus.unknown));
    test('missing key', () => expect(parse('$hdr\r\n    Hash    REG_SZ    abc=\r\n'), DefaultStatus.unknown));
  });

  group('queryDefaults', () {
    test('unsupported platform is all unknown', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final svc = DefaultAppService.test(runner: (_, __) => throw StateError('no process'));
      final r = await svc.queryDefaults();
      expect(r.length, DocumentType.values.length);
      expect(r.values.toSet(), {DefaultStatus.unknown});
    });

    test('linux uses runner per mime and never throws', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final calls = <List<String>>[];
      final svc = DefaultAppService.test(runner: (e, a) async {
        calls.add([e, ...a]);
        if (a.last == 'application/pdf') return ProcessResult(0, 0, 'openreader.desktop\n', '');
        if (a.last == 'text/csv') throw const ProcessException('xdg-mime', []);
        if (a.last == 'text/plain') return ProcessResult(0, 0, 'gedit.desktop\n', '');
        return ProcessResult(0, 1, '', 'err');
      });
      final r = await svc.queryDefaults();
      expect(r[DocumentType.pdf], DefaultStatus.isDefault);
      expect(r[DocumentType.text], DefaultStatus.otherApp);
      expect(r[DocumentType.csv], DefaultStatus.unknown);
      expect(r[DocumentType.word], DefaultStatus.unknown);
      expect(calls.first.take(3), ['xdg-mime', 'query', 'default']);
    });

    test('windows queries the per-type ProgId', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final svc = DefaultAppService.test(runner: (e, a) async {
        expect(e, 'reg');
        if (a[1].contains(r'\.pdf\')) return ProcessResult(0, 0, '    ProgId    REG_SZ    OpenReader.pdf\r\n', '');
        return ProcessResult(0, 0, '    ProgId    REG_SZ    Other.App\r\n', '');
      });
      final r = await svc.queryDefaults();
      expect(r[DocumentType.pdf], DefaultStatus.isDefault);
      expect(r[DocumentType.word], DefaultStatus.otherApp);
    });

    test('macOS maps the channel reply and tolerates missing entries', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('openreader/open_files'),
        (call) async => {'pdf': true, 'docx': false},
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('openreader/open_files'), null));
      final r = await DefaultAppService.test().queryDefaults();
      expect(r[DocumentType.pdf], DefaultStatus.isDefault);
      expect(r[DocumentType.word], DefaultStatus.otherApp);
      expect(r[DocumentType.excel], DefaultStatus.unknown);
    });
  });

  test('openSystemDefaultAppsSettings: Windows runs ms-settings, others false', () async {
    final calls = <List<String>>[];
    final svc = DefaultAppService.test(runner: (e, a) async {
      calls.add([e, ...a]);
      return ProcessResult(0, 0, '', '');
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(await svc.openSystemDefaultAppsSettings(), isFalse);
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(await svc.openSystemDefaultAppsSettings(), isTrue);
    expect(calls.single.last, 'ms-settings:defaultapps');
  });

  test('resetPrompt clears dismissed and shown keys', () async {
    SharedPreferences.setMockInitialValues({'default_app_prompt_dismissed': true, 'default_app_prompt_shown': 3});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final svc = DefaultAppService.test();
    expect(await svc.shouldPrompt(), isFalse);
    await svc.resetPrompt();
    expect(await svc.shouldPrompt(), isTrue);
  });

  group('StorageAccessService.state', () {
    test('mapping', () {
      StorageAccessState f(bool g, bool p) => StorageAccessService.stateFrom(granted: g, permanentlyDenied: p);
      expect(f(true, false), StorageAccessState.allowed);
      expect(f(false, false), StorageAccessState.notAllowed);
      expect(f(false, true), StorageAccessState.blocked);
    });
    for (final p in [TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
      test('notApplicable on $p', () async {
        debugDefaultTargetPlatformOverride = p;
        expect(await StorageAccessService.instance.state(), StorageAccessState.notApplicable);
      });
    }
  });
}
