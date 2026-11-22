import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/services/utilities/other_installs.dart';
import 'package:path/path.dart' as p;

WindowsUninstallEntry entry({
  String key = 'x_is1',
  String name = 'OpenReader version 1.0.21',
  String publisher = 'OpenReader',
  String location = r'C:\Users\a\AppData\Local\Programs\OpenReaderOld\',
  String uninstall = r'"C:\Users\a\AppData\Local\Programs\OpenReaderOld\unins000.exe"',
  String hive = 'HKCU',
}) => WindowsUninstallEntry(
  hive: hive,
  key: key,
  name: name,
  publisher: publisher,
  version: '1.0.21',
  location: location,
  uninstall: uninstall,
);

String jsonString(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

void main() {
  group('parseUninstallCommand', () {
    test('a quoted program with and without arguments', () {
      final a = OtherInstalls.parseUninstallCommand(r'"C:\Program Files\X\unins000.exe"')!;
      expect(a.executable, r'C:\Program Files\X\unins000.exe');
      expect(a.arguments, isEmpty);
      final b = OtherInstalls.parseUninstallCommand(r'"C:\X\unins000.exe" /SILENT /LOG')!;
      expect(b.arguments, ['/SILENT', '/LOG']);
    });

    test('an unquoted path, an unterminated quote and nothing', () {
      expect(OtherInstalls.parseUninstallCommand(r'C:\X\unins000.exe /SILENT')!.executable, r'C:\X\unins000.exe');
      expect(OtherInstalls.parseUninstallCommand('"C:\\X\\unins000.exe'), isNull);
      expect(OtherInstalls.parseUninstallCommand('   '), isNull);
    });
  });

  group('parseWindowsUninstallJson', () {
    test('an array, a single object, nothing and garbage', () {
      const one =
          '{"hive":"HKCU","key":"k","name":"OpenReader","publisher":"OpenReader","version":"1","location":"L","uninstall":"U"}';
      expect(OtherInstalls.parseWindowsUninstallJson('[$one,$one]'), hasLength(2));
      expect(OtherInstalls.parseWindowsUninstallJson(one).single.location, 'L');
      expect(OtherInstalls.parseWindowsUninstallJson(''), isEmpty);
      expect(OtherInstalls.parseWindowsUninstallJson('not json'), isEmpty);
    });

    test('null fields become empty strings', () {
      final e = OtherInstalls.parseWindowsUninstallJson('[{"name":"OpenReader","publisher":null}]').single;
      expect(e.publisher, '');
      expect(e.uninstall, '');
    });
  });

  group('windowsRemovable', () {
    const current = r'C:\Users\a\AppData\Local\Programs\OpenReader';
    bool exists(String path) => true;

    List<WindowsUninstallEntry> removable(List<WindowsUninstallEntry> entries, {bool Function(String)? ex}) =>
        OtherInstalls.windowsRemovable(entries, currentDir: current, exists: ex ?? exists);

    test('another OpenReader install is removable', () {
      expect(removable([entry()]), hasLength(1));
    });

    test('the install being updated is never removed, with or without a trailing slash or other case', () {
      final same = entry(
        location: r'c:\users\A\appdata\local\programs\openreader\',
        uninstall: r'"C:\Users\a\AppData\Local\Programs\OpenReader\unins000.exe"',
      );
      expect(removable([same]), isEmpty);
      // Located by its uninstaller even when the registry has no InstallLocation.
      expect(
        removable([entry(location: '', uninstall: r'"C:\Users\a\AppData\Local\Programs\OpenReader\unins000.exe"')]),
        isEmpty,
      );
    });

    test('the old OpenDocs name and a per-machine install are removable', () {
      final old = entry(
        name: 'OpenDocs version 0.9',
        key: 'old_is1',
        location: r'C:\Program Files\OpenDocs',
        uninstall: r'"C:\Program Files\OpenDocs\unins000.exe"',
        hive: 'HKLM',
      );
      expect(removable([old]), hasLength(1));
    });

    test('the installer AppId alone identifies an install, whatever its publisher or folder', () {
      final byId = entry(
        key: '{${OtherInstalls.windowsAppId}}_is1'.toLowerCase(),
        publisher: '',
        location: r'D:\Apps\Reader',
      );
      expect(removable([byId]), hasLength(1));
    });

    test('something that is not clearly ours is left alone', () {
      expect(removable([entry(key: 'other_is1', publisher: 'Someone Else', location: r'C:\Foo')]), isEmpty);
      expect(removable([entry(name: 'Open Source Tool')]), isEmpty);
      expect(removable([entry(name: 'MyOpenReader')]), isEmpty);
    });

    test('only an Inno uninstaller that exists is run', () {
      expect(removable([entry(uninstall: r'"C:\X\uninstall.exe"')]), isEmpty, reason: 'uninstall.exe is anyone\'s');
      expect(removable([entry(uninstall: r'"C:\X\unins000.bat"')]), isEmpty);
      expect(removable([entry(uninstall: '')]), isEmpty);
      expect(removable([entry()], ex: (_) => false), isEmpty);
      expect(removable([entry(uninstall: r'MsiExec.exe /X{ABC}')]), isEmpty);
    });
  });

  group('macOS', () {
    test('bundles to remove: not the running one, not on a volume, not in the Trash, not a build', () {
      final found = OtherInstalls.macBundleCandidates([
        '/Applications/OpenReader.app',
        '/Users/a/Downloads/OpenReader.app',
        '/Volumes/OpenReader/OpenReader.app',
        '/Users/a/.Trash/OpenReader.app',
        '/Users/a/dev/build/macos/Build/Products/Release/OpenReader.app',
        '/Applications/Other.txt',
        '  /Users/a/Applications/OpenDocs.app  ',
      ], currentBundle: '/Applications/OpenReader.app');
      expect(found, ['/Users/a/Downloads/OpenReader.app', '/Users/a/Applications/OpenDocs.app']);
    });
  });

  group('Linux', () {
    test('the program a launcher starts', () {
      expect(
        OtherInstalls.desktopExecPath('[Desktop Entry]\nName=OpenReader\nExec=/home/a/openreader/openreader %F\nIcon=x'),
        '/home/a/openreader/openreader',
      );
      expect(OtherInstalls.desktopExecPath('Exec="/home/a/my apps/openreader" %F'), '/home/a/my apps/openreader');
      expect(OtherInstalls.desktopExecPath('Exec=openreader'), 'openreader');
      expect(OtherInstalls.desktopExecPath('Name=OpenReader'), isNull);
    });

    test('only a plain extracted tarball inside the home folder may be deleted', () {
      final full = {
        '/home/a/openreader/openreader',
        '/home/a/openreader/data/flutter_assets',
        '/home/a/openreader/install-desktop-entry.sh',
      };
      bool in_(Set<String> files, String path) => files.contains(p.posix.normalize(path));

      expect(OtherInstalls.looksLikeTarballInstall('/home/a/openreader', home: '/home/a', exists: (x) => in_(full, x)), isTrue);
      // Missing the installer script: not plainly ours.
      final partial = {...full}..remove('/home/a/openreader/install-desktop-entry.sh');
      expect(OtherInstalls.looksLikeTarballInstall('/home/a/openreader', home: '/home/a', exists: (x) => in_(partial, x)), isFalse);
      // Outside the home folder, the home folder itself, and an unknown home.
      expect(OtherInstalls.looksLikeTarballInstall('/opt/openreader', home: '/home/a', exists: (_) => true), isFalse);
      expect(OtherInstalls.looksLikeTarballInstall('/home/a', home: '/home/a', exists: (_) => true), isFalse);
      expect(OtherInstalls.looksLikeTarballInstall('/home/a/openreader', home: '', exists: (_) => true), isFalse);
    });
  });

  group('removeAll', () {
    late Directory temporary;
    setUp(() async => temporary = await Directory.systemTemp.createTemp('openreader-installs-'));
    tearDown(() async => temporary.delete(recursive: true));

    test('runs each other install\'s uninstaller silently and never the current one', () async {
      final oldDir = Directory(p.join(temporary.path, 'OpenReaderOld'))..createSync();
      final uninstaller = File(p.join(oldDir.path, 'unins000.exe'))..writeAsStringSync('x');
      final currentDir = Directory(p.join(temporary.path, 'OpenReader'))..createSync();
      File(p.join(currentDir.path, 'unins000.exe')).writeAsStringSync('x');
      final calls = <String>[];
      final json =
          '[{"hive":"HKCU","key":"a_is1","name":"OpenDocs version 0.9","publisher":"OpenReader","version":"0.9",'
          '"location":${jsonString(oldDir.path)},"uninstall":${jsonString('"${uninstaller.path}"')}},'
          '{"hive":"HKCU","key":"b_is1","name":"OpenReader version 1.0.22","publisher":"OpenReader","version":"1.0.22",'
          '"location":${jsonString(currentDir.path)},"uninstall":${jsonString('"${p.join(currentDir.path, 'unins000.exe')}"')}}]';

      final result = await OtherInstalls(
        operatingSystem: 'windows',
        currentExecutable: p.join(currentDir.path, 'openreader.exe'),
        run: (exe, args) async {
          if (exe == 'powershell') return ProcessResult(0, 0, json, '');
          calls.add('$exe ${args.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
      ).removeAll();

      expect(result.found, 1);
      expect(result.removed, 1);
      expect(calls, ['${uninstaller.path} /VERYSILENT /SUPPRESSMSGBOXES /NORESTART']);
    }, skip: !Platform.isWindows);

    test('a failing uninstaller is reported and does not throw', () async {
      final oldDir = Directory(p.join(temporary.path, 'OpenReaderOld'))..createSync();
      final uninstaller = File(p.join(oldDir.path, 'unins000.exe'))..writeAsStringSync('x');
      final json =
          '[{"hive":"HKCU","key":"a_is1","name":"OpenReader version 1","publisher":"OpenReader","version":"1",'
          '"location":${jsonString(oldDir.path)},"uninstall":${jsonString('"${uninstaller.path}"')}}]';

      final result = await OtherInstalls(
        operatingSystem: 'windows',
        currentExecutable: p.join(temporary.path, 'elsewhere', 'openreader.exe'),
        run: (exe, args) async => exe == 'powershell' ? ProcessResult(0, 0, json, '') : ProcessResult(0, 1, '', 'failed'),
      ).removeAll();

      expect(result.removed, 0);
      expect(result.failed, hasLength(1));
    }, skip: !Platform.isWindows);

    test('an unknown system or a failing lookup finds nothing and does not throw', () async {
      final none = await OtherInstalls(operatingSystem: 'fuchsia').removeAll();
      expect(none.found, 0);
      final broken = await OtherInstalls(
        operatingSystem: 'windows',
        run: (exe, args) async => throw const ProcessException('powershell', []),
      ).removeAll();
      expect(broken.found, 0);
    });

    test('with the real registry: a fake OpenDocs entry is found and its uninstaller runs', () async {
      const root = r'HKCU:\Software\OpenReaderInstallsTest';
      const key = r'HKCU\Software\OpenReaderInstallsTest\fake_is1';
      final marker = File(p.join(temporary.path, 'uninstalled.txt'));
      final oldDir = Directory(p.join(temporary.path, 'OpenDocsOld'))..createSync();
      // A stand-in for Inno's uninstaller: records its arguments instead of removing anything.
      final fake = File(p.join(oldDir.path, 'unins000.cmd'))
        ..writeAsStringSync('@echo off\r\necho %* > "${marker.path}"\r\nexit /b 0\r\n');
      Future<void> reg(List<String> args) => Process.run('reg', args);
      try {
        await reg(['add', key, '/v', 'DisplayName', '/d', 'OpenDocs version 0.9', '/f']);
        await reg(['add', key, '/v', 'Publisher', '/d', 'OpenReader', '/f']);
        await reg(['add', key, '/v', 'InstallLocation', '/d', oldDir.path, '/f']);
        await reg(['add', key, '/v', 'UninstallString', '/d', '"${fake.path}"', '/f']);

        final result = await OtherInstalls(
          operatingSystem: 'windows',
          windowsUninstallRoots: [root],
          // The stand-in is a .cmd, not Inno's unins000.exe.
          uninstallerName: RegExp(r'^unins\d+\.cmd$'),
          currentExecutable: p.join(temporary.path, 'current', 'openreader.exe'),
        ).removeAll();

        expect(result.found, 1);
        expect(result.removed, 1);
        expect(marker.existsSync(), isTrue);
        expect(marker.readAsStringSync(), contains('/VERYSILENT'));
      } finally {
        await reg(['delete', r'HKCU\Software\OpenReaderInstallsTest', '/f']);
      }
    }, skip: !Platform.isWindows);
  });
}
