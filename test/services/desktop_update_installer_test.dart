import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/services/utilities/desktop_update_installer.dart';
import 'package:path/path.dart' as p;

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
    test('accepts the release-assets redirect target with its long query string', () {
      final url = 'https://release-assets.githubusercontent.com/github-production-release-asset/123/'
          'abc-def?sp=r&sv=2018-11-09&sr=b&spr=https&se=2026-11-21T10%3A00%3A00Z&rscd=attachment%3B+filename%3DOpenReader-windows-x64.zip&${'x' * 600}=1';
      expect(DesktopUpdateInstaller.isTrustedUpdateUrl(url), isTrue);
    });
    test('rejects a non-default port', () {
      expect(DesktopUpdateInstaller.isTrustedUpdateUrl('https://github.com:8443/a.zip'), isFalse);
      expect(DesktopUpdateInstaller.isTrustedUpdateUrl('https://github.com:443/a.zip'), isTrue);
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

  group('redirects (getFollowingRedirects)', () {
    late HttpServer server;
    late String base;
    late HttpClient client;
    final hits = <String>[];

    Future<void> serve(void Function(HttpRequest r) handler) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((r) {
        hits.add(r.uri.toString());
        handler(r);
        // handlers close the response themselves
      });
    }

    setUp(() {
      hits.clear();
      client = HttpClient();
    });
    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    bool localOnly(String url) => url.startsWith(base);

    test('follows an absolute and a relative Location, with a long query, to the file', () async {
      final longQuery = 'sig=${'a' * 1500}&rscd=attachment%3B+filename%3Dx.zip';
      await serve((r) {
        if (r.uri.path == '/dl') {
          r.response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '$base/assets/1?$longQuery');
        } else if (r.uri.path == '/assets/1') {
          r.response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '/final/x.zip?$longQuery');
        } else {
          r.response.write('payload');
        }
        r.response.close();
      });
      final res = await DesktopUpdateInstaller.getFollowingRedirects(client, '$base/dl', isTrusted: localOnly);
      expect(res.statusCode, 200);
      expect(await res.transform(const SystemEncoding().decoder).join(), 'payload');
      expect(hits.length, 3);
      expect(hits.last, startsWith('/final/x.zip?sig='));
    });

    test('an untrusted hop is refused before it is requested', () async {
      await serve((r) {
        r.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, 'https://evil.example.com/a.zip');
        r.response.close();
      });
      await expectLater(
        DesktopUpdateInstaller.getFollowingRedirects(client, '$base/dl', isTrusted: localOnly),
        throwsA(isA<UnsafeUpdateUrlException>()),
      );
      expect(hits.length, 1);
    });

    test('more than 6 hops fails', () async {
      await serve((r) {
        r.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/loop');
        r.response.close();
      });
      await expectLater(
        DesktopUpdateInstaller.getFollowingRedirects(client, '$base/loop', isTrusted: localOnly),
        throwsA(isA<UpdateInstallException>().having((e) => e.message, 'message', contains('too many redirects'))),
      );
      expect(hits.length, 6);
    });

    test('a redirect without Location fails', () async {
      await serve((r) {
        r.response.statusCode = HttpStatus.found;
        r.response.close();
      });
      await expectLater(
        DesktopUpdateInstaller.getFollowingRedirects(client, '$base/x', isTrusted: localOnly),
        throwsA(isA<UpdateInstallException>()),
      );
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

    // Script text only: these tests do not run PowerShell (pwsh is not needed or used).
    test('windows zip script copies with Get-ChildItem, not a wildcard LiteralPath', () {
      final s = DesktopUpdateInstaller.buildWindowsUpdateScript(
        pid: 1,
        staged: r'C:\st[1]',
        target: r'C:\app',
        exe: r'C:\app\a.exe',
        scriptDir: r'C:\up\u_x',
        viaInstaller: false,
      );
      expect(s, isNot(contains("'*'")));
      expect(s, isNot(matches(RegExp(r"Copy-Item -LiteralPath"))));
      expect(s, contains(r"Get-ChildItem -LiteralPath 'C:\st[1]' -Force | Copy-Item -Destination 'C:\app' -Recurse -Force"));
      // A copy that never succeeded is reported and stops before relaunching.
      expect(s, contains('if (-not \$copied)'));
      expect(s, contains('openreader_update_failed.log'));
      expect(s, contains('exit 1'));
      expect(s.indexOf('exit 1'), lessThan(s.indexOf('Start-Process -FilePath')));
    });

    test('macOS script swaps via .new/.old and restores on failure', () {
      final s = DesktopUpdateInstaller.buildPosixUpdateScript(macos: true);
      expect(s, contains(r'ditto "$3" "$2.new"'));
      expect(s, contains(r'mv "$2" "$2.old"'));
      expect(s, contains(r'mv "$2.new" "$2"'));
      expect(s, contains(r'mv "$2.old" "$2"'));
      expect(s, contains(r'rm -rf -- "$2.old"'));
      expect(s.indexOf(r'ditto "$3" "$2.new"'), lessThan(s.indexOf(r'mv "$2" "$2.old"')));
    });

    test('macOS swap logic works with sh (ditto stubbed by cp) and restores when the swap fails', () async {
      if (Platform.isWindows) return;
      final root = await Directory.systemTemp.createTemp('upd_mac_');
      addTearDown(() => root.delete(recursive: true));
      final bin = Directory('${root.path}/bin')..createSync();
      File('${bin.path}/ditto').writeAsStringSync('#!/bin/sh\ncp -R "\$1" "\$2"\n');
      File('${bin.path}/open').writeAsStringSync('#!/bin/sh\nexit 0\n');
      await Process.run('chmod', ['+x', '${bin.path}/ditto', '${bin.path}/open']);
      final app = Directory('${root.path}/Old.app')..createSync();
      File('${app.path}/v').writeAsStringSync('old');
      final staged = Directory('${root.path}/st/New.app')..createSync(recursive: true);
      File('${staged.path}/v').writeAsStringSync('new');
      final sd = Directory('${root.path}/sd')..createSync();
      final script = File('${sd.path}/update.sh')..writeAsStringSync(DesktopUpdateInstaller.buildPosixUpdateScript(macos: true));
      final r = await Process.run('/bin/sh', [script.path, '999999999', app.path, staged.path, sd.path, '/usr/bin/true'],
          environment: {'PATH': '${bin.path}:/usr/bin:/bin'});
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(File('${app.path}/v').readAsStringSync(), 'new');
      expect(Directory('${app.path}.old').existsSync(), isFalse);
      expect(Directory('${app.path}.new').existsSync(), isFalse);

      // A failing copy leaves the installed app untouched.
      File('${bin.path}/ditto').writeAsStringSync('#!/bin/sh\nexit 1\n');
      final sd2 = Directory('${root.path}/sd2')..createSync();
      final script2 = File('${sd2.path}/update.sh')..writeAsStringSync(DesktopUpdateInstaller.buildPosixUpdateScript(macos: true));
      await Process.run('/bin/sh', [script2.path, '999999999', app.path, staged.path, sd2.path, '/usr/bin/true'],
          environment: {'PATH': '${bin.path}:/usr/bin:/bin'});
      expect(File('${app.path}/v').readAsStringSync(), 'new');
      expect(Directory('${app.path}.new').existsSync(), isFalse);
    });

    test('stagingRoot is the folder that holds the download, mount and staged dirs', () {
      expect(DesktopUpdateInstaller.stagingRoot('/t/openreader_update/u_1/staged/OpenReader.app'), '/t/openreader_update/u_1');
      expect(DesktopUpdateInstaller.stagingRoot('/t/openreader_update/u_1/staged'), '/t/openreader_update/u_1');
      expect(DesktopUpdateInstaller.stagingRoot('/t/openreader_update/u_1/setup.exe'), '/t/openreader_update/u_1');
    });
  });

  group('staging dir', () {
    test('linux uses the per-user support dir, not /tmp', () {
      final base = DesktopUpdateInstaller.stagingBasePath(
          isLinux: true,
          tempPath: '/tmp',
          supportPath: '/home/u/.local/share/openreader');
      // The path is joined with the host's separator, so expect it the same way.
      expect(base, p.join('/home/u/.local/share/openreader', 'updates'));
      expect(base, isNot(p.join('/tmp', 'openreader_update')));
    });
    test('others keep the temporary directory', () {
      expect(
          DesktopUpdateInstaller.stagingBasePath(
              isLinux: false, tempPath: '/t', supportPath: ''),
          p.join('/t', 'openreader_update'));
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
