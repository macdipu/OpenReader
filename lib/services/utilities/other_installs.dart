import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/presentation/utils/logger.dart';

/// Another copy of OpenReader found on this computer, and how to remove it.
class OtherInstall {
  OtherInstall({required this.description, required this.remove});

  /// What it is and where, for the log.
  final String description;

  /// Removes it. True when it is gone.
  final Future<bool> Function() remove;
}

/// What [OtherInstalls.removeAll] did.
class OtherInstallsResult {
  const OtherInstallsResult({required this.found, required this.removed, required this.failed});

  final int found;
  final int removed;
  final List<String> failed;
}

/// An entry of Windows' installed-programs list.
class WindowsUninstallEntry {
  const WindowsUninstallEntry({
    required this.hive,
    required this.key,
    required this.name,
    required this.publisher,
    required this.version,
    required this.location,
    required this.uninstall,
  });

  final String hive;
  final String key;
  final String name;
  final String publisher;
  final String version;
  final String location;
  final String uninstall;
}

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Finds other installed versions of OpenReader and removes them, before an update installs
/// (CR-FILE-RELOCATE, desktop). Two versions at once happen when an app was installed in more than one
/// way (installer and zip, package and tarball) or under an earlier name (OpenDocs).
///
/// What is never touched: the running install, anything that does not clearly identify itself as
/// OpenReader or OpenDocs, and the user's documents and settings. A failure to remove one never stops
/// the update.
class OtherInstalls {
  OtherInstalls({
    ProcessRunner? run,
    String? currentExecutable,
    String? home,
    List<String>? windowsUninstallRoots,
    String? bundleId,
    String? operatingSystem,
    RegExp? uninstallerName,
    this.removeTimeout = const Duration(minutes: 2),
  }) : _run = run ?? Process.run,
       _currentExecutable = currentExecutable ?? Platform.resolvedExecutable,
       _home = home ?? Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '',
       _windowsUninstallRoots = windowsUninstallRoots ?? defaultWindowsUninstallRoots,
       _bundleId = bundleId ?? 'com.chowdhuryelab.openreader',
       _os = operatingSystem ?? Platform.operatingSystem,
       _uninstallerName = uninstallerName ?? defaultUninstallerName;

  final ProcessRunner _run;
  final String _currentExecutable;
  final String _home;
  final List<String> _windowsUninstallRoots;
  final String _bundleId;
  final String _os;
  final RegExp _uninstallerName;
  final Duration removeTimeout;

  /// The Inno Setup AppId of the OpenReader installer (windows/installer/openreader.iss).
  static const windowsAppId = '6D3B7A52-4C1E-4F0B-9A55-0E7B1D2C9F41';

  /// Inno Setup names its uninstaller unins000.exe, unins001.exe and so on. Not "uninstall.exe", which
  /// is anyone's.
  static final defaultUninstallerName = RegExp(r'^unins\d+\.exe$', caseSensitive: false);

  static const defaultWindowsUninstallRoots = [
    r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    r'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    r'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
  ];

  /// Finds and removes every other install. Never throws.
  Future<OtherInstallsResult> removeAll() async {
    final List<OtherInstall> installs;
    try {
      installs = await find();
    } catch (e) {
      AppLogger.warning('[INSTALLS] could not look for other installs: $e');
      return const OtherInstallsResult(found: 0, removed: 0, failed: []);
    }
    var removed = 0;
    final failed = <String>[];
    for (final install in installs) {
      try {
        if (await install.remove().timeout(removeTimeout, onTimeout: () => false)) {
          removed++;
          AppLogger.info('[INSTALLS] removed ${install.description}');
        } else {
          failed.add(install.description);
          AppLogger.warning('[INSTALLS] could not remove ${install.description}');
        }
      } catch (e) {
        failed.add(install.description);
        AppLogger.warning('[INSTALLS] could not remove ${install.description}: $e');
      }
    }
    return OtherInstallsResult(found: installs.length, removed: removed, failed: failed);
  }

  Future<List<OtherInstall>> find() {
    return switch (_os) {
      'windows' => _findWindows(),
      'macos' => _findMacOS(),
      'linux' => _findLinux(),
      _ => Future.value(const <OtherInstall>[]),
    };
  }

  // ---------------------------------------------------------------------------
  // Windows
  // ---------------------------------------------------------------------------

  Future<List<OtherInstall>> _findWindows() async {
    final result = await _run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      windowsQueryScript(_windowsUninstallRoots),
    ]);
    if (result.exitCode != 0) return const [];
    final entries = parseWindowsUninstallJson('${result.stdout}');
    final currentDir = p.dirname(_currentExecutable);
    return [
      for (final entry in windowsRemovable(entries, currentDir: currentDir, uninstallerName: _uninstallerName))
        OtherInstall(
          description: 'Windows install "${entry.name}" (${entry.hive}) at ${entry.location}',
          remove: () => _runWindowsUninstall(entry),
        ),
    ];
  }

  Future<bool> _runWindowsUninstall(WindowsUninstallEntry entry) async {
    final command = parseUninstallCommand(entry.uninstall);
    if (command == null) return false;
    // Inno Setup's silent switches: no windows, no message boxes, no restart.
    final args = [...command.arguments, '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'];
    final result = await _run(command.executable, args);
    return result.exitCode == 0;
  }

  /// PowerShell that prints the OpenReader/OpenDocs entries under [roots] as JSON.
  static String windowsQueryScript(List<String> roots) {
    final quoted = roots.map((r) => "'$r'").join(',');
    return "\$r = foreach (\$k in $quoted) { if (Test-Path \$k) { foreach (\$i in Get-ChildItem \$k) { "
        "\$p = Get-ItemProperty \$i.PSPath; if (\$p.DisplayName -match '^(OpenReader|OpenDocs)\\b') { "
        "[pscustomobject]@{hive=\$k.Substring(0,4);key=\$i.PSChildName;name=\$p.DisplayName;publisher=\$p.Publisher;"
        "version=\$p.DisplayVersion;location=\$p.InstallLocation;uninstall=\$p.UninstallString} } } } }; "
        // -InputObject @(...) always gives an array and works in Windows PowerShell 5.1 (no -AsArray there).
        "if (\$r) { ConvertTo-Json -InputObject @(\$r) -Compress }";
  }

  /// Parses [windowsQueryScript]'s output: a JSON array, or nothing.
  static List<WindowsUninstallEntry> parseWindowsUninstallJson(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return const [];
    }
    final list = decoded is List ? decoded : [decoded];
    String field(Map<dynamic, dynamic> m, String key) => (m[key] as String?) ?? '';
    return [
      for (final item in list)
        if (item is Map)
          WindowsUninstallEntry(
            hive: field(item, 'hive'),
            key: field(item, 'key'),
            name: field(item, 'name'),
            publisher: field(item, 'publisher'),
            version: field(item, 'version'),
            location: field(item, 'location'),
            uninstall: field(item, 'uninstall'),
          ),
    ];
  }

  static String _normalizeDir(String path) => p.normalize(path).replaceAll(RegExp(r'[\\/]+$'), '').toLowerCase();

  /// The entries that are another OpenReader install and can be removed silently: named OpenReader
  /// or OpenDocs, and identified as ours (the installer's AppId, our publisher, or our folder name);
  /// not the install at [currentDir]; with an uninstaller that exists and is an Inno one (`unins000.exe`).
  static List<WindowsUninstallEntry> windowsRemovable(
    List<WindowsUninstallEntry> entries, {
    required String currentDir,
    bool Function(String path)? exists,
    RegExp? uninstallerName,
  }) {
    final fileExists = exists ?? (path) => File(path).existsSync();
    final innoName = uninstallerName ?? defaultUninstallerName;
    final ours = RegExp(r'^(openreader|opendocs)$', caseSensitive: false);
    final current = _normalizeDir(currentDir);
    final out = <WindowsUninstallEntry>[];
    for (final entry in entries) {
      if (!RegExp(r'^(openreader|opendocs)\b', caseSensitive: false).hasMatch(entry.name)) continue;
      final identified = entry.key.toUpperCase().contains(windowsAppId) ||
          ours.hasMatch(entry.publisher.trim()) ||
          ours.hasMatch(p.basename(_normalizeDir(entry.location)));
      if (!identified) continue;
      final command = parseUninstallCommand(entry.uninstall);
      if (command == null) continue;
      if (!innoName.hasMatch(p.basename(command.executable))) continue;
      if (!fileExists(command.executable)) continue;
      // The install being updated is the one this process runs from.
      if (_normalizeDir(entry.location) == current || _normalizeDir(p.dirname(command.executable)) == current) {
        continue;
      }
      out.add(entry);
    }
    return out;
  }

  /// Splits a registry UninstallString (`"C:\x\unins000.exe" /arg` or an unquoted path) into the
  /// program and its arguments. Null when it is empty.
  static ({String executable, List<String> arguments})? parseUninstallCommand(String command) {
    final text = command.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('"')) {
      final end = text.indexOf('"', 1);
      if (end < 0) return null;
      final rest = text.substring(end + 1).trim();
      return (executable: text.substring(1, end), arguments: rest.isEmpty ? <String>[] : rest.split(RegExp(r'\s+')));
    }
    final exe =
        RegExp(r'^.*?\.exe\b', caseSensitive: false).firstMatch(text)?.group(0) ?? text.split(RegExp(r'\s+')).first;
    final rest = text.substring(exe.length).trim();
    return (executable: exe, arguments: rest.isEmpty ? <String>[] : rest.split(RegExp(r'\s+')));
  }

  // ---------------------------------------------------------------------------
  // macOS
  // ---------------------------------------------------------------------------

  Future<List<OtherInstall>> _findMacOS() async {
    // X.app/Contents/MacOS/x -> X.app
    final current = p.posix.dirname(p.posix.dirname(p.posix.dirname(_currentExecutable)));
    final found = <String>{};
    final spotlight = await _run('mdfind', ['kMDItemCFBundleIdentifier == "$_bundleId"']);
    if (spotlight.exitCode == 0) found.addAll(const LineSplitter().convert('${spotlight.stdout}'));
    // Spotlight can be off or slow to index: also look where apps are usually put, for either name.
    for (final dir in [
      '/Applications',
      p.posix.join(_home, 'Applications'),
      p.posix.join(_home, 'Downloads'),
      p.posix.join(_home, 'Desktop'),
    ]) {
      for (final name in ['OpenReader.app', 'OpenDocs.app']) {
        final candidate = p.posix.join(dir, name);
        if (Directory(candidate).existsSync()) found.add(candidate);
      }
    }
    final result = <OtherInstall>[];
    for (final path in macBundleCandidates(found, currentBundle: current)) {
      if (!await _isOurBundle(path)) continue;
      result.add(OtherInstall(description: 'macOS app $path', remove: () => _moveToTrash(path)));
    }
    return result;
  }

  /// Bundles from [paths] that may be removed: an `.app`, not the running one, not on a mounted disk
  /// image or volume, not already in the Trash, not a build product.
  static List<String> macBundleCandidates(Iterable<String> paths, {required String currentBundle}) {
    final current = p.posix.normalize(currentBundle);
    return [
      for (final raw in paths)
        if (raw.trim().endsWith('.app'))
          if (p.posix.normalize(raw.trim()) != current &&
              !p.posix.normalize(raw.trim()).startsWith('/Volumes/') &&
              !raw.contains('/.Trash/') &&
              !raw.contains('/build/macos/'))
            p.posix.normalize(raw.trim()),
    ];
  }

  static const _macBundleIds = {'com.chowdhuryelab.openreader', 'com.chowdhuryelab.opendocs'};

  Future<bool> _isOurBundle(String app) async {
    final result = await _run('defaults', ['read', p.posix.join(app, 'Contents', 'Info'), 'CFBundleIdentifier']);
    return result.exitCode == 0 && _macBundleIds.contains('${result.stdout}'.trim().toLowerCase());
  }

  /// Moves [app] to the Trash, so removing it can be undone.
  Future<bool> _moveToTrash(String app) async {
    final trash = Directory(p.posix.join(_home, '.Trash'));
    if (!trash.existsSync()) return false;
    var target = p.posix.join(trash.path, p.posix.basename(app));
    if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
      target = p.posix.join(
        trash.path,
        '${p.posix.basenameWithoutExtension(app)} ${DateTime.now().millisecondsSinceEpoch}.app',
      );
    }
    try {
      await Directory(app).rename(target);
      return true;
    } on FileSystemException {
      // Another volume, or a folder this user cannot change: let Finder do it.
      final result = await _run('osascript', ['-e', 'tell application "Finder" to delete POSIX file "$app"']);
      return result.exitCode == 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Linux
  // ---------------------------------------------------------------------------

  Future<List<OtherInstall>> _findLinux() async {
    final current = _currentExecutable;
    // The .deb and .rpm install under /opt/openreader and /usr/bin.
    final runningFromPackage = current.startsWith('/opt/openreader/') || current.startsWith('/usr/');
    final installs = <OtherInstall>[];

    if (!runningFromPackage) {
      for (final name in ['openreader', 'opendocs']) {
        if (await _debInstalled(name)) {
          installs.add(
            OtherInstall(
              description: 'Debian package $name',
              remove: () async => (await _run('pkexec', ['apt-get', 'remove', '-y', name])).exitCode == 0,
            ),
          );
        } else if (await _rpmInstalled(name)) {
          installs.add(
            OtherInstall(
              description: 'RPM package $name',
              remove: () async => (await _run('pkexec', ['rpm', '-e', name])).exitCode == 0,
            ),
          );
        }
      }
    }

    // Launcher entries of this user (the tarball's install-desktop-entry.sh) and the folders they
    // point at.
    final dataHome = Platform.environment['XDG_DATA_HOME'] ?? p.posix.join(_home, '.local', 'share');
    final apps = Directory(p.posix.join(dataHome, 'applications'));
    if (apps.existsSync()) {
      for (final entity in apps.listSync().whereType<File>()) {
        final name = p.posix.basename(entity.path).toLowerCase();
        if (!(name == 'openreader.desktop' || name == 'opendocs.desktop')) continue;
        final exec = desktopExecPath(entity.readAsStringSync());
        if (exec == null || p.posix.normalize(exec) == p.posix.normalize(current)) continue;
        installs.add(
          OtherInstall(
            description: 'Linux launcher ${entity.path} -> $exec',
            remove: () => _removeLinuxUserInstall(entity, exec),
          ),
        );
      }
    }
    return installs;
  }

  Future<bool> _debInstalled(String name) async {
    final r = await _run('dpkg-query', ['-W', '-f=\${Status}', name]);
    return r.exitCode == 0 && '${r.stdout}'.contains('install ok installed');
  }

  Future<bool> _rpmInstalled(String name) async => (await _run('rpm', ['-q', name])).exitCode == 0;

  /// The program a `.desktop` file starts: the `Exec=` command without its arguments (`%F` and so on).
  static String? desktopExecPath(String content) {
    for (final line in const LineSplitter().convert(content)) {
      if (!line.startsWith('Exec=')) continue;
      var exec = line.substring(5).trim();
      if (exec.startsWith('"')) {
        final end = exec.indexOf('"', 1);
        return end < 0 ? null : exec.substring(1, end);
      }
      exec = exec.split(RegExp(r'\s+(?=%|-)')).first.trim();
      return exec.isEmpty ? null : exec;
    }
    return null;
  }

  /// Whether [dir] is an extracted OpenReader tarball inside [home]: the program, the Flutter assets
  /// and the launcher script are all there. Anything else is left alone.
  static bool looksLikeTarballInstall(String dir, {required String home, bool Function(String path)? exists}) {
    final present = exists ?? (path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
    if (home.isEmpty || !p.posix.isWithin(home, dir)) return false;
    return present(p.posix.join(dir, 'openreader')) &&
        present(p.posix.join(dir, 'data', 'flutter_assets')) &&
        present(p.posix.join(dir, 'install-desktop-entry.sh'));
  }

  Future<bool> _removeLinuxUserInstall(File launcher, String exec) async {
    final dir = p.posix.dirname(exec);
    final apps = p.posix.dirname(launcher.path);
    // The launcher entry and icon always go; the folder only when it is plainly an OpenReader tarball
    // (or already gone, which is how a stale entry looks).
    try {
      if (launcher.existsSync()) launcher.deleteSync();
      final icon = File(p.posix.join(apps, '..', 'icons', 'hicolor', '512x512', 'apps', 'openreader.png'));
      if (icon.existsSync()) icon.deleteSync();
      if (Directory(dir).existsSync() && looksLikeTarballInstall(dir, home: _home)) {
        await Directory(dir).delete(recursive: true);
      }
      return true;
    } on FileSystemException catch (e) {
      AppLogger.warning('[INSTALLS] could not remove $dir: $e');
      return false;
    }
  }
}
