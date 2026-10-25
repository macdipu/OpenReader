import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/presentation/utils/platform_info.dart';
import '../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../core/presentation/widgets/update/app_update_sheet.dart';
import 'url_launcher_service.dart';

/// Tells the user when a newer build is out:
/// - Android: Google Play's in-app updates API.
/// - Windows/macOS/Linux: the latest GitHub release, which the release
///   workflow (.github/workflows/release.yml) attaches desktop builds to.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _latestReleaseUrl = 'https://api.github.com/repos/macdipu/OpenReader/releases/latest';

  bool _checked = false;

  /// Checks once per app session and offers a newer build in
  /// [AppUpdateSheet]. Silent when there's nothing to offer or the check
  /// fails (offline, rate-limited, or an Android build not installed from Play).
  Future<void> checkForUpdate() async {
    if (_checked || kIsWeb) return;
    _checked = true;

    if (PlatformInfo.isAndroid) {
      await _checkPlayStore();
    } else if (PlatformInfo.isDesktop) {
      await _checkGitHubRelease();
    }
  }

  // ---------------------------------------------------------------------------
  // Android - Google Play
  // ---------------------------------------------------------------------------

  Future<void> _checkPlayStore() async {
    final AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (_) {
      return;
    }

    if (info.installStatus == InstallStatus.downloaded) {
      _promptRestart();
      return;
    }
    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
    if (!info.flexibleUpdateAllowed && !info.immediateUpdateAllowed) return;

    final accepted = await showAppUpdateSheet(
      message: 'A new version of OpenReader is ready. It downloads in the background, so you can keep reading.',
    );
    if (accepted != true) return;

    try {
      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) _promptRestart();
      } else {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      CustomSnackbar.error('Could not download the update. Try again from Google Play.');
    }
  }

  /// The flexible download finished; installing restarts the app, so it's
  /// the user's call when.
  void _promptRestart() {
    CustomSnackbar.show(
      message: 'Update downloaded.',
      type: SnackbarType.success,
      duration: const Duration(seconds: 10),
      actionLabel: 'Restart',
      onAction: InAppUpdate.completeFlexibleUpdate,
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop - GitHub Releases
  // ---------------------------------------------------------------------------

  Future<void> _checkGitHubRelease() async {
    final Map<String, dynamic> release;
    try {
      release = await _fetchLatestRelease();
    } catch (_) {
      return;
    }

    final tag = release['tag_name'] as String? ?? '';
    final latest = _parseVersion(tag);
    final current = _parseVersion((await PackageInfo.fromPlatform()).version);
    if (latest == null || current == null || _compare(latest, current) <= 0) return;

    // Only offer a release that actually has a build for this platform.
    final asset = (release['assets'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((a) => (a['name'] as String? ?? '').startsWith(_assetPrefix))
        .firstOrNull;
    final downloadUrl = asset?['browser_download_url'] as String?;
    if (downloadUrl == null) return;

    final accepted = await showAppUpdateSheet(
      message: 'OpenReader $tag is available. Download it, then replace this copy with the new one.',
      actionLabel: 'Download',
    );
    if (accepted != true) return;

    final result = await UrlLauncherService.instance.launch(downloadUrl);
    result.fold((_) => CustomSnackbar.error('Could not open the download link.'), (_) {});
  }

  /// Asset names from release.yml's "Package <platform>" steps.
  String get _assetPrefix {
    if (PlatformInfo.isWindows) return 'openreader-windows-';
    if (PlatformInfo.isMacOS) return 'openreader-macos-';
    return 'openreader-linux-';
  }

  Future<Map<String, dynamic>> _fetchLatestRelease() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(_latestReleaseUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}');
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// `v1.2.3` / `1.2.3` -> [1, 2, 3]. Null for anything else, such as the
  /// workflow's `build-<n>` test tags.
  static List<int>? _parseVersion(String value) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(value.trim());
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}
