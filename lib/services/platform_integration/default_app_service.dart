import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/presentation/utils/logger.dart';
import '../../core/presentation/utils/platform_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A document type the user can make OpenReader the default app for.
enum DocumentType {
  pdf('PDF', 'pdf', 'application/pdf'),
  word('Word', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  excel('Excel', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  powerpoint('PowerPoint', 'pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'),
  csv('CSV', 'csv', 'text/csv'),
  text('Text', 'txt', 'text/plain'),
  markdown('Markdown', 'md', 'text/markdown');

  final String label;
  final String extension;
  final String mimeType;
  const DocumentType(this.label, this.extension, this.mimeType);
}

/// Outcome of [DefaultAppService.makeDefault].
class DefaultAppResult {
  /// True when OpenReader is now the default; false when the OS needs the user
  /// to confirm (Windows) and the right settings screen was opened.
  final bool applied;
  final bool success;
  final String message;
  const DefaultAppResult({required this.applied, required this.success, required this.message});
}

/// Whether OpenReader is the system default for a document type.
/// [unknown] whenever the platform cannot say reliably; never a guess.
enum DefaultStatus { isDefault, otherApp, unknown }

/// Runs an external command; replaced in tests so no process is spawned.
typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// "Make OpenReader the default app" - for all documents or chosen types.
///
/// - Linux: `xdg-mime default` per type (sets it directly).
/// - macOS: `NSWorkspace.setDefaultApplication` per type (macOS asks the user to confirm).
/// - Windows: apps cannot set a default silently (the choice is protected), so it registers
///   OpenReader and opens Settings > Default apps with OpenReader selected.
/// - Android / iOS: unsupported, so the prompt and the settings row are never shown.
class DefaultAppService {
  DefaultAppService._();
  @visibleForTesting
  DefaultAppService.test({ProcessRunner? runner}) : _run = runner ?? Process.run;
  static final DefaultAppService instance = DefaultAppService._();

  ProcessRunner _run = Process.run;

  static const _macChannel = MethodChannel('openreader/open_files');
  static const _dismissedKey = 'default_app_prompt_dismissed';
  static const _shownKey = 'default_app_prompt_shown';
  static const _maxPrompts = 3;

  /// Desktop only: Android and iOS expose no supported way to become the default document app.
  bool get isSupported => PlatformInfo.isDesktop;

  /// Whether this platform can set the default itself (versus sending the user to settings).
  bool get appliesDirectly => PlatformInfo.isLinux || PlatformInfo.isMacOS;

  /// The first-run prompt appears a few times at most, and never after "Don't ask again".
  Future<bool> shouldPrompt() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissedKey) ?? false) return false;
    return (prefs.getInt(_shownKey) ?? 0) < _maxPrompts;
  }

  Future<void> recordPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shownKey, (prefs.getInt(_shownKey) ?? 0) + 1);
  }

  Future<void> dismissPromptForever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  /// Clears the first-run prompt's "shown" count and "don't ask again" flag so it can appear again.
  Future<void> resetPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
    await prefs.remove(_shownKey);
  }

  /// Opens the system's default-apps settings. Windows only; false elsewhere or on failure.
  Future<bool> openSystemDefaultAppsSettings() async {
    if (!PlatformInfo.isWindows) return false;
    try {
      final r = await _run('cmd', ['/c', 'start', '', 'ms-settings:defaultapps']);
      return r.exitCode == 0;
    } catch (e, st) {
      AppLogger.error('openSystemDefaultAppsSettings failed', e, st);
      return false;
    }
  }

  /// Whether OpenReader is the default for each [DocumentType]. Never throws; an unsupported
  /// platform, a missing tool or unreadable output gives [DefaultStatus.unknown].
  Future<Map<DocumentType, DefaultStatus>> queryDefaults() async {
    final result = {for (final t in DocumentType.values) t: DefaultStatus.unknown};
    try {
      if (PlatformInfo.isLinux) {
        for (final t in DocumentType.values) {
          result[t] = await _guard(() async {
            final r = await _run('xdg-mime', ['query', 'default', t.mimeType]);
            return r.exitCode == 0 ? parseXdgDefault('${r.stdout}') : DefaultStatus.unknown;
          });
        }
      } else if (PlatformInfo.isWindows) {
        for (final t in DocumentType.values) {
          result[t] = await _guard(() async {
            final r = await _run('reg', [
              'query',
              'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FileExts\\.${t.extension}\\UserChoice',
              '/v',
              'ProgId',
            ]);
            return r.exitCode == 0
                ? parseWindowsProgId('${r.stdout}', appProgId: windowsProgId(t))
                : DefaultStatus.unknown;
          });
        }
      } else if (PlatformInfo.isMacOS) {
        final raw = await _macChannel.invokeMethod<Map<Object?, Object?>>(
          'queryDefaultForExtensions',
          DocumentType.values.map((t) => t.extension).toList(),
        );
        for (final t in DocumentType.values) {
          final v = raw?[t.extension];
          if (v is bool) result[t] = v ? DefaultStatus.isDefault : DefaultStatus.otherApp;
        }
      }
    } catch (e, st) {
      AppLogger.error('queryDefaults failed', e, st);
    }
    return result;
  }

  Future<DefaultStatus> _guard(Future<DefaultStatus> Function() body) async {
    try {
      return await body();
    } catch (_) {
      return DefaultStatus.unknown;
    }
  }

  /// The per-type ProgId that windows/register-file-types.ps1 registers (e.g. `OpenReader.pdf`).
  @visibleForTesting
  static String windowsProgId(DocumentType t) => 'OpenReader.${t.extension}';

  /// `xdg-mime query default` prints the desktop file name. Empty or anything that is not a single
  /// `.desktop` token is [DefaultStatus.unknown].
  @visibleForTesting
  static DefaultStatus parseXdgDefault(String stdout) {
    final name = stdout.trim();
    if (!RegExp(r'^[^\s/]+\.desktop$').hasMatch(name)) return DefaultStatus.unknown;
    return name.toLowerCase() == 'openreader.desktop' ? DefaultStatus.isDefault : DefaultStatus.otherApp;
  }

  /// Parses `reg query ... /v ProgId` output (`    ProgId    REG_SZ    <value>`).
  @visibleForTesting
  static DefaultStatus parseWindowsProgId(String stdout, {required String appProgId}) {
    final m = RegExp(r'^\s*ProgId\s+REG_SZ\s+(\S.*?)\s*$', multiLine: true, caseSensitive: false).firstMatch(stdout);
    if (m == null) return DefaultStatus.unknown;
    return m.group(1)!.toLowerCase() == appProgId.toLowerCase() ? DefaultStatus.isDefault : DefaultStatus.otherApp;
  }

  Future<DefaultAppResult> makeDefault(Set<DocumentType> types) async {
    if (types.isEmpty) {
      return const DefaultAppResult(applied: false, success: false, message: 'Choose at least one file type.');
    }
    try {
      if (PlatformInfo.isLinux) return await _linux(types);
      if (PlatformInfo.isMacOS) return await _macos(types);
      if (PlatformInfo.isWindows) return await _windows(types);
    } catch (e, st) {
      AppLogger.error('makeDefault failed', e, st);
    }
    return const DefaultAppResult(applied: false, success: false, message: 'Could not change the default app.');
  }

  /// Whether `openreader.desktop` is installed where the system looks for applications: the user's
  /// data directory, or any of XDG_DATA_DIRS (/usr/share and /usr/local/share by default, which is
  /// where the .deb and .rpm put it).
  bool _hasDesktopEntry() {
    final home = Platform.environment['HOME'] ?? '';
    final dirs = <String>[
      Platform.environment['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share'),
      ...(Platform.environment['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share').split(':').where((d) => d.isNotEmpty),
    ];
    return dirs.any((dir) => File(p.join(dir, 'applications', 'openreader.desktop')).existsSync());
  }

  String _list(Set<DocumentType> types) => types.map((t) => '.${t.extension}').join(', ');

  Future<DefaultAppResult> _linux(Set<DocumentType> types) async {
    if (!_hasDesktopEntry()) {
      // A .deb / .rpm installs the entry system-wide, so it is found above. Without one (the
      // tarball, an AppImage), the entry is made for the user from the bundle's script if it has one.
      final script = File(p.join(p.dirname(Platform.resolvedExecutable), 'install-desktop-entry.sh'));
      if (!script.existsSync()) {
        return const DefaultAppResult(
            applied: false,
            success: false,
            message: 'OpenReader is not installed as an app on this system. Install the .deb or .rpm, '
                'or run install-desktop-entry.sh from the OpenReader folder, then try again.');
      }
      await Process.run('sh', [script.path]);
    }
    final failed = <DocumentType>[];
    for (final type in types) {
      final r = await Process.run('xdg-mime', ['default', 'openreader.desktop', type.mimeType]);
      if (r.exitCode != 0) failed.add(type);
    }
    if (failed.isNotEmpty) {
      return DefaultAppResult(applied: false, success: false, message: 'Could not set ${_list(failed.toSet())}. Is xdg-utils installed?');
    }
    return DefaultAppResult(applied: true, success: true, message: 'OpenReader now opens ${_list(types)} files.');
  }

  Future<DefaultAppResult> _macos(Set<DocumentType> types) async {
    final failed = await _macChannel.invokeMethod<List<Object?>>(
      'setDefaultForExtensions',
      types.map((t) => t.extension).toList(),
    );
    final failedTypes = types.where((t) => (failed ?? const []).contains(t.extension)).toSet();
    if (failedTypes.length == types.length) {
      return const DefaultAppResult(applied: false, success: false, message: 'macOS did not accept the change.');
    }
    final ok = types.difference(failedTypes);
    return DefaultAppResult(applied: true, success: true, message: 'OpenReader now opens ${_list(ok)} files.');
  }

  Future<DefaultAppResult> _windows(Set<DocumentType> types) async {
    final exe = Platform.resolvedExecutable;
    final script = File(p.join(p.dirname(exe), 'register-file-types.ps1'));
    if (script.existsSync()) {
      await Process.run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script.path, '-ExePath', exe]);
    }
    // registeredAppUser preselects OpenReader in the per-type list.
    await Process.run('cmd', ['/c', 'start', '', 'ms-settings:defaultapps?registeredAppUser=OpenReader']);
    return DefaultAppResult(
      applied: false,
      success: true,
      message: 'In Windows Settings, choose OpenReader for ${_list(types)}.',
    );
  }
}
