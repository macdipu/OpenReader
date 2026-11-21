import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/services/utilities/desktop_update_installer.dart';

final _h = 'a' * 64;
final _h2 = 'B' * 64;

void main() {
  group('isTrustedUpdateUrl', () {
    test('accepts https github hosts', () {
      expect(
          DesktopUpdateInstaller.isTrustedUpdateUrl(
              'https://github.com/macdipu/OpenReader/releases/download/v1/a.zip'),
          isTrue);
      expect(
          DesktopUpdateInstaller.isTrustedUpdateUrl(
              'https://objects.githubusercontent.com/x/y?z=1'),
          isTrue);
    });
    test('rejects http, other hosts, lookalikes, userinfo, garbage', () {
      for (final u in [
        'http://github.com/a.zip',
        'https://evil.com/a.zip',
        'https://github.com.evil.com/a.zip',
        'https://evilgithub.com/a.zip',
        'https://api.github.com/a.zip',
        'https://github.com@evil.com/a.zip',
        'ftp://github.com/a',
        'file:///etc/passwd',
        '',
        'not a url',
      ]) {
        expect(DesktopUpdateInstaller.isTrustedUpdateUrl(u), isFalse, reason: u);
      }
    });
  });

  group('SHA256SUMS', () {
    final sums = DesktopUpdateInstaller.parseSha256Sums(
        '$_h  openreader-a.zip\n$_h2 *b file.dmg\r\nnot a line\n${'c' * 63}  short\n');
    test('parses text and binary mode lines, lowercases, skips junk', () {
      expect(sums, {'openreader-a.zip': _h, 'b file.dmg': _h2.toLowerCase()});
    });
    test('match passes, mismatch throws', () {
      DesktopUpdateInstaller.verifyChecksum(_h, _h.toUpperCase());
      expect(() => DesktopUpdateInstaller.verifyChecksum(_h, _h2),
          throwsA(isA<UpdateInstallException>()));
    });
    test('missing entry throws', () {
      expect(DesktopUpdateInstaller.expectedChecksum(sums, 'openreader-a.zip'),
          _h);
      expect(() => DesktopUpdateInstaller.expectedChecksum(sums, 'other.zip'),
          throwsA(isA<UpdateInstallException>()));
    });
  });

  group('scripts', () {
    test('posix scripts contain no paths, only argument references', () {
      for (final macos in [true, false]) {
        final s = DesktopUpdateInstaller.buildPosixUpdateScript(macos: macos);
        expect(s, contains(r'$2'));
        expect(s, contains(r'$4'));
        expect(s, isNot(contains('xattr')));
        expect(s, isNot(contains('quarantine')));
      }
    });

    test('posix script is safe when run with hostile paths', () async {
      if (Platform.isWindows) return;
      final root = await Directory.systemTemp.createTemp('upd_test_');
      addTearDown(() => root.delete(recursive: true));
      final target = Directory('${root.path}/ta rget\'"\$(touch pwned)`');
      final staged = Directory('${root.path}/st aged \$HOME');
      await target.create();
      await staged.create();
      await File('${staged.path}/new.txt').writeAsString('x');
      final scriptDir = Directory('${root.path}/sd \'q\'');
      await scriptDir.create();
      final script = File('${scriptDir.path}/update.sh')
        ..writeAsStringSync(
            DesktopUpdateInstaller.buildPosixUpdateScript(macos: false));
      final r = await Process.run('/bin/sh', [
        script.path,
        '999999999',
        target.path,
        staged.path,
        scriptDir.path,
        '/usr/bin/true'
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(File('${target.path}/new.txt').existsSync(), isTrue);
      expect(File('${root.path}/pwned').existsSync(), isFalse);
      expect(scriptDir.existsSync(), isFalse);
    });

    test('psQuote escapes quotes and leaves \$ and backtick literal', () {
      expect(DesktopUpdateInstaller.psQuote(r'C:\a b\c'), r"'C:\a b\c'");
      expect(DesktopUpdateInstaller.psQuote("it's"), "'it''s'");
      expect(DesktopUpdateInstaller.psQuote('a"b'), "'a\"b'");
      expect(DesktopUpdateInstaller.psQuote(r'$env:X `n $(calc)'),
          r"'$env:X `n $(calc)'");
      expect(DesktopUpdateInstaller.psQuote('\u2019x\u2018'),
          "'\u2019\u2019x\u2018\u2018'");
    });

    test('windows script quotes every path', () {
      const staged = r"C:\up d\st'aged $x";
      const target = r'C:\Program Files\Open"Reader';
      final s = DesktopUpdateInstaller.buildWindowsUpdateScript(
        pid: 42,
        staged: staged,
        target: target,
        exe: r'C:\a\b `c`.exe',
        scriptDir: r'C:\sd',
        viaInstaller: false,
      );
      expect(s, contains("'C:\\up d\\st''aged \$x'"));
      expect(s, contains("'C:\\Program Files\\Open\"Reader'"));
      expect(s, contains("'C:\\a\\b `c`.exe'"));
      expect(s, isNot(contains('"C:')));
      expect(s, contains('Get-Process -Id 42'));
    });
  });

  group('staging dir', () {
    test('linux uses the per-user support dir, not /tmp', () {
      final base = DesktopUpdateInstaller.stagingBasePath(
          isLinux: true,
          tempPath: '/tmp',
          supportPath: '/home/u/.local/share/openreader');
      expect(base, '/home/u/.local/share/openreader/updates');
      expect(base, isNot('/tmp/openreader_update'));
    });
    test('others keep the temporary directory', () {
      expect(
          DesktopUpdateInstaller.stagingBasePath(
              isLinux: false, tempPath: '/t', supportPath: ''),
          '/t/openreader_update');
    });
    test('createStagingDir makes a unique 0700 directory', () async {
      if (Platform.isWindows) return;
      final root = await Directory.systemTemp.createTemp('upd_base_');
      addTearDown(() => root.delete(recursive: true));
      final a = await DesktopUpdateInstaller.createStagingDir('${root.path}/updates');
      expect(a.statSync().mode & 0x1FF, 448); // 0700
      expect(Directory('${root.path}/updates').statSync().mode & 0x1FF, 448);
      final b = await DesktopUpdateInstaller.createStagingDir('${root.path}/updates');
      expect(b.path, isNot(a.path));
    });
  });
}
