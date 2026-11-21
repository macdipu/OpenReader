import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/presentation/utils/platform_info.dart';

/// Thrown when an update can't be installed in place (read-only install
/// location, AppImage, a tool missing). Callers fall back to the browser.
class UpdateInstallException implements Exception {
  final String message;
  UpdateInstallException(this.message);
  @override
  String toString() => message;
}

/// The download or checksum URL is not one we trust (not https, or a host
/// outside [DesktopUpdateInstaller.allowedHosts]). Callers open the release
/// page in the browser instead.
class UnsafeUpdateUrlException extends UpdateInstallException {
  UnsafeUpdateUrlException(super.message);
}

/// Cancels an in-flight [DesktopUpdateInstaller.download].
class UpdateCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Downloads a release build, stages it, and swaps it in once the app exits:
/// - Windows: the release .zip, copied over the install folder.
/// - macOS:   the .dmg, whose OpenReader.app replaces the running bundle.
/// - Linux:   the .tar.gz, copied over the install folder.
/// The swap runs in a detached helper script that waits for this process to
/// exit, so no file is replaced while in use.
class DesktopUpdateInstaller {
  DesktopUpdateInstaller._();

  /// Whether [name] is this platform's build among a release's assets
  /// (names come from the "Package <platform>" steps in release.yml).
  static bool isPlatformAsset(String name) {
    final n = name.toLowerCase();
    if (PlatformInfo.isWindows) {
      // Installed with setup.exe: update through it, so shortcuts, "Open with" and the
      // uninstall entry stay consistent. A portable unzipped copy gets the zip.
      if (_isInstallerInstall) {
        return n.startsWith('openreader-') && n.endsWith('-windows-x64-setup.exe');
      }
      return n.startsWith('openreader-windows-') && n.endsWith('.zip');
    }
    if (PlatformInfo.isMacOS)
      return n.startsWith('openreader-') && n.endsWith('-macos.dmg');
    return n.startsWith('openreader-linux-') && n.endsWith('.tar.gz');
  }

  /// Inno Setup drops its uninstaller (unins000.exe) next to the app.
  static bool get _isInstallerInstall =>
      PlatformInfo.isWindows &&
      File(p.join(p.dirname(Platform.resolvedExecutable), 'unins000.exe'))
          .existsSync();

  /// Directory the running app lives in (Windows/Linux) or the .app bundle (macOS).
  static String get _installTarget {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    if (PlatformInfo.isMacOS)
      return p.dirname(p.dirname(exeDir)); // X.app/Contents/MacOS/x -> X.app
    return exeDir;
  }

  /// Throws [UpdateInstallException] early (before a big download) when this
  /// install can't be replaced in place.
  static Future<void> ensureInstallable() async {
    if (PlatformInfo.isLinux && Platform.environment.containsKey('APPIMAGE')) {
      throw UpdateInstallException(
          'AppImage installs update by downloading the new AppImage.');
    }
    final target = _installTarget;
    // macOS replaces the bundle, so its parent must be writable; elsewhere the folder itself.
    final probeDir = PlatformInfo.isMacOS ? p.dirname(target) : target;
    try {
      final probe = File(p.join(probeDir, '.openreader_write_test'));
      await probe.writeAsString('');
      await probe.delete();
    } on FileSystemException {
      throw UpdateInstallException(
          'No permission to update the install location ($probeDir).');
    }
  }

  // ---------------------------------------------------------------------------
  // Pure, unit-tested helpers
  // ---------------------------------------------------------------------------

  /// Hosts a release download (and each redirect hop) may come from.
  static const allowedHosts = {'github.com', 'objects.githubusercontent.com'};

  /// True for `https` URLs on [allowedHosts] only.
  static bool isTrustedUpdateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        allowedHosts.contains(uri.host.toLowerCase());
  }

  /// Parses `sha256sum` output (`<64 hex>  <name>` or `<64 hex> *<name>`) into
  /// name -> lowercase hash. Lines that do not match are ignored.
  static Map<String, String> parseSha256Sums(String text) {
    final out = <String, String>{};
    final line = RegExp(r'^([0-9a-fA-F]{64}) [ *](.+)$');
    for (final raw in const LineSplitter().convert(text)) {
      final m = line.firstMatch(raw.trimRight());
      if (m == null) continue;
      out[m.group(2)!] = m.group(1)!.toLowerCase();
    }
    return out;
  }

  /// The checksum [fileName] must have, or an [UpdateInstallException] when
  /// the release's SHA256SUMS has no entry for it.
  static String expectedChecksum(Map<String, String> sums, String fileName) {
    final hash = sums[fileName];
    if (hash == null) {
      throw UpdateInstallException(
          'The release has no checksum for $fileName, so the update was not installed.');
    }
    return hash;
  }

  /// Throws when [actualSha256] differs from [expectedSha256].
  static void verifyChecksum(String expectedSha256, String actualSha256) {
    if (expectedSha256.toLowerCase() != actualSha256.toLowerCase()) {
      throw UpdateInstallException(
          'The downloaded update does not match its published checksum, so it was not installed.');
    }
  }

  /// Where to stage updates. Linux uses the per-user application support
  /// directory, never a shared, predictable path in /tmp.
  static String stagingBasePath({
    required bool isLinux,
    required String tempPath,
    required String supportPath,
  }) =>
      isLinux
          ? p.join(supportPath, 'updates')
          : p.join(tempPath, 'openreader_update');

  /// A fresh, unpredictable staging directory (mode 0700 on POSIX).
  static Future<Directory> createStagingDir(String basePath) async {
    final base = Directory(basePath);
    if (await base.exists()) await base.delete(recursive: true);
    await base.create(recursive: true);
    if (!Platform.isWindows) await Process.run('chmod', ['700', base.path]);
    final dir = await base.createTemp('u_');
    if (!Platform.isWindows) await Process.run('chmod', ['700', dir.path]);
    return dir;
  }

  /// PowerShell single-quoted literal: no expansion of `$` or backticks; every
  /// quote character PowerShell accepts (including the typographic ones) is doubled.
  static String psQuote(String value) {
    final b = StringBuffer("'");
    for (final r in value.runes) {
      final c = String.fromCharCode(r);
      b.write(const {"'", '\u2018', '\u2019', '\u201A', '\u201B'}.contains(c)
          ? '$c$c'
          : c);
    }
    b.write("'");
    return b.toString();
  }

  /// POSIX helper script. It contains no paths: they arrive as arguments
  /// `$1` pid, `$2` install target, `$3` staged, `$4` script dir, `$5` app executable.
  static String buildPosixUpdateScript({required bool macos}) {
    final swap = macos
        ? '''rm -rf -- "\$2"
ditto "\$3" "\$2"
open "\$2"'''
        : '''cp -a "\$3/." "\$2/"
nohup "\$5" >/dev/null 2>&1 &''';
    return '''#!/bin/sh
while kill -0 "\$1" 2>/dev/null; do sleep 0.3; done
$swap
rm -rf -- "\$4"
''';
  }

  /// Windows helper script; every path is a [psQuote]d literal.
  static String buildWindowsUpdateScript({
    required int pid,
    required String staged,
    required String target,
    required String exe,
    required String scriptDir,
    required bool viaInstaller,
  }) {
    final apply = viaInstaller
        ? "Start-Process -FilePath ${psQuote(staged)} -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CLOSEAPPLICATIONS' -Wait"
        : '''for (\$i = 0; \$i -lt 20; \$i++) {
  try { Copy-Item -LiteralPath (Join-Path ${psQuote(staged)} '*') -Destination ${psQuote(target)} -Recurse -Force; break }
  catch { Start-Sleep -Milliseconds 500 }
}''';
    return '''\$ErrorActionPreference = 'Stop'
while (Get-Process -Id $pid -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 300 }
$apply
Start-Process -FilePath ${psQuote(exe)}
Remove-Item -Recurse -Force -LiteralPath ${psQuote(scriptDir)} -ErrorAction SilentlyContinue
''';
  }

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  /// GET [url] following redirects by hand so every hop is checked against
  /// [isTrustedUpdateUrl]. The caller closes [client].
  static Future<HttpClientResponse> _get(HttpClient client, String url) async {
    var current = url;
    for (var hop = 0; hop < 6; hop++) {
      if (!isTrustedUpdateUrl(current)) {
        throw UnsafeUpdateUrlException(
            'The update link is not from a trusted address.');
      }
      final request = await client.getUrl(Uri.parse(current));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'OpenReader-Updater');
      final response = await request.close();
      const redirects = {
        HttpStatus.movedPermanently,
        HttpStatus.found,
        HttpStatus.seeOther,
        HttpStatus.temporaryRedirect,
        HttpStatus.permanentRedirect,
      };
      if (!redirects.contains(response.statusCode)) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) {
        throw UpdateInstallException('Download failed (bad redirect).');
      }
      current = Uri.parse(current).resolve(location).toString();
    }
    throw UpdateInstallException('Download failed (too many redirects).');
  }

  /// Fetches the release's SHA256SUMS ([url] must pass the same host rules).
  static Future<Map<String, String>> fetchChecksums(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final response =
          await _get(client, url).timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateInstallException(
            'Could not get the update checksums (HTTP ${response.statusCode}).');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) {
          throw UpdateInstallException('The checksum list is too large.');
        }
      }
      return parseSha256Sums(utf8.decode(bytes, allowMalformed: true));
    } on SocketException catch (e) {
      throw UpdateInstallException('Could not get the update checksums: ${e.message}');
    } on TimeoutException {
      throw UpdateInstallException('Could not get the update checksums in time.');
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads [url] and verifies it against [expectedSha256]; a mismatch
  /// deletes the file and throws. [onProgress] gets 0..1 (or null when unknown).
  static Future<File> download(String url,
      {required String expectedSha256,
      required void Function(double? progress) onProgress,
      required UpdateCancelToken cancel}) async {
    if (!isTrustedUpdateUrl(url)) {
      throw UnsafeUpdateUrlException(
          'The update link is not from a trusted address.');
    }
    final base = stagingBasePath(
      isLinux: PlatformInfo.isLinux,
      tempPath: (await getTemporaryDirectory()).path,
      supportPath: PlatformInfo.isLinux
          ? (await getApplicationSupportDirectory()).path
          : '',
    );
    final dir = await createStagingDir(base);

    var name = p.basename(Uri.parse(url).path);
    if (name.isEmpty || name == '.' || name == '..') name = 'update.bin';
    final file = File(p.join(dir.path, name));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    try {
      final response = await _get(client, url);
      if (response.statusCode != HttpStatus.ok)
        throw UpdateInstallException(
            'Download failed (HTTP ${response.statusCode}).');

      final total = response.contentLength;
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in response) {
        if (cancel.isCancelled)
          throw UpdateInstallException('Download cancelled.');
        sink.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : null);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      final actual = (await sha256.bind(file.openRead()).first).toString();
      try {
        verifyChecksum(expectedSha256, actual);
      } on UpdateInstallException {
        await dir.delete(recursive: true).catchError((_) => dir);
        rethrow;
      }
      return file;
    } on SocketException catch (e) {
      throw UpdateInstallException('Download failed: ${e.message}');
    } finally {
      await sink?.close().catchError((_) {});
      client.close(force: true);
    }
  }

  /// Unpacks the download next to it and returns what to copy over the install:
  /// the extracted folder (Windows/Linux) or the new .app (macOS).
  static Future<String> stage(File archive) async {
    // The Windows installer runs as-is; nothing to unpack.
    if (archive.path.toLowerCase().endsWith('.exe')) return archive.path;

    final out = Directory(p.join(archive.parent.path, 'staged'));
    await out.create(recursive: true);

    if (PlatformInfo.isMacOS) {
      final mount = p.join(archive.parent.path, 'mount');
      await Directory(mount).create();
      await _run('hdiutil', [
        'attach',
        '-nobrowse',
        '-readonly',
        '-noverify',
        '-mountpoint',
        mount,
        archive.path
      ]);
      try {
        final app = Directory(mount)
            .listSync()
            .whereType<Directory>()
            .where((d) => d.path.endsWith('.app'))
            .firstOrNull;
        if (app == null)
          throw UpdateInstallException(
              'The update disk image has no app in it.');
        final dest = p.join(out.path, p.basename(app.path));
        await _run('ditto', [app.path, dest]);
        return dest;
      } finally {
        await Process.run('hdiutil', ['detach', '-force', mount]);
      }
    }

    // bsdtar ships with Windows 10+ and reads .zip; GNU tar reads .tar.gz.
    await _run('tar', ['-xf', archive.path, '-C', out.path]);
    return out.path;
  }

  /// Starts the detached helper that swaps [staged] in after this process exits.
  /// The caller must exit the app right after.
  static Future<void> launchInstallerAndRelaunch(String staged) async {
    final target = _installTarget;
    final exe = Platform.resolvedExecutable;
    final scriptDir = p.dirname(staged);

    if (PlatformInfo.isWindows) {
      final script = File(p.join(scriptDir, 'update.ps1'));
      // BOM so Windows PowerShell 5.1 reads non-ASCII paths as UTF-8.
      await script.writeAsString(
          '\uFEFF${buildWindowsUpdateScript(pid: pid, staged: staged, target: target, exe: exe, scriptDir: scriptDir, viaInstaller: staged.toLowerCase().endsWith('.exe'))}');
      // NOTE: spawning powershell directly with ProcessStartMode.detached
      // silently dies on Windows (child exits before running the script).
      // Routing through `cmd /c start /b` keeps the child alive - verified
      // against a live update flow.
      await Process.start(
        'cmd',
        [
          '/c',
          'start',
          '/b',
          'powershell',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path,
        ],
        mode: ProcessStartMode.detached,
      );
      return;
    }

    final script = File(p.join(scriptDir, 'update.sh'));
    await script.writeAsString(buildPosixUpdateScript(macos: PlatformInfo.isMacOS));
    // Paths go in as arguments, never into the script text.
    await Process.start(
        '/bin/sh', [script.path, '$pid', target, staged, scriptDir, exe],
        mode: ProcessStartMode.detached);
  }

  static Future<void> _run(String cmd, List<String> args) async {
    final ProcessResult r;
    try {
      r = await Process.run(cmd, args);
    } on ProcessException catch (e) {
      throw UpdateInstallException('Could not run $cmd: ${e.message}');
    }
    if (r.exitCode != 0)
      throw UpdateInstallException(
          '$cmd failed: ${(r.stderr as String).trim()}');
  }
}
