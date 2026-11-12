import 'dart:async';
import 'dart:io';

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

  /// Downloads [url]; [onProgress] gets 0..1 (or null when the size is unknown).
  static Future<File> download(String url,
      {required void Function(double? progress) onProgress,
      required UpdateCancelToken cancel}) async {
    final dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'openreader_update'));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, p.basename(Uri.parse(url).path)));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
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
      final viaInstaller = staged.toLowerCase().endsWith('.exe');
      final apply = viaInstaller
          ? 'Start-Process -FilePath "${_ps(staged)}" -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART","/CLOSEAPPLICATIONS" -Wait'
          : '''for (\$i = 0; \$i -lt 20; \$i++) {
  try { Copy-Item -Path "${_ps(staged)}\\*" -Destination "${_ps(target)}" -Recurse -Force; break }
  catch { Start-Sleep -Milliseconds 500 }
}''';
      await script.writeAsString('''
\$ErrorActionPreference = "Stop"
while (Get-Process -Id $pid -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 300 }
$apply
Start-Process -FilePath "${_ps(exe)}"
Remove-Item -Recurse -Force "${_ps(scriptDir)}" -ErrorAction SilentlyContinue
''');
      await Process.start(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path
        ],
        mode: ProcessStartMode.detached,
      );
      return;
    }

    final script = File(p.join(scriptDir, 'update.sh'));
    if (PlatformInfo.isMacOS) {
      await script.writeAsString('''
#!/bin/sh
while kill -0 $pid 2>/dev/null; do sleep 0.3; done
rm -rf "$target"
ditto "$staged" "$target"
xattr -dr com.apple.quarantine "$target" 2>/dev/null
open "$target"
rm -rf "$scriptDir"
''');
    } else {
      await script.writeAsString('''
#!/bin/sh
while kill -0 $pid 2>/dev/null; do sleep 0.3; done
cp -a "$staged/." "$target/"
nohup "$exe" >/dev/null 2>&1 &
rm -rf "$scriptDir"
''');
    }
    await Process.start('/bin/sh', [script.path],
        mode: ProcessStartMode.detached);
  }

  static String _ps(String path) =>
      path.replaceAll('`', '``').replaceAll('"', '`"');

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
