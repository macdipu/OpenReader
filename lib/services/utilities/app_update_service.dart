import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/presentation/utils/platform_info.dart';
import '../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../core/presentation/widgets/update/desktop/app_update_available_dialog.dart';
import '../../core/presentation/widgets/update/mobile/app_update_available_sheet.dart';
import '../../core/presentation/widgets/update/desktop/app_update_progress.dart';
import '../../res/routes/global_navigator.dart';
import 'desktop_update_installer.dart';
import 'update_checker.dart';
import 'update_decision.dart';
import 'url_launcher_service.dart';

/// Tells the user when a newer build is out:
/// - Android: Google Play's in-app updates API.
/// - Windows/macOS/Linux: the latest GitHub release, which the release
///   workflow (.github/workflows/release.yml) attaches desktop builds to.
class AppUpdateService implements UpdateActions {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _latestReleaseUrl =
      'https://api.github.com/repos/macdipu/OpenReader/releases/latest';
  static const _releasePageUrl =
      'https://github.com/macdipu/OpenReader/releases/latest';

  bool _checked = false;

  final _checker = UpdateChecker();

  /// Asks the store and GitHub what is newest (Settings > About > Version).
  Future<UpdateCheck> check() => _checker.check();

  @override
  Future<void> startStoreUpdate(UpdateCheck check) async {
    final info = check.playInfo;
    if (info == null) return openStore(check);
    await _runPlayUpdate(info);
  }

  @override
  Future<void> openStore(UpdateCheck check) => _openInBrowser(
    check.storeUrl ?? 'https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader',
  );

  /// The early build: the APK for this phone from the GitHub release, handed to the browser's download (the
  /// user installs it from there, which Android asks them to allow), or the release page when no APK matches.
  @override
  Future<void> downloadEarlyBuild(UpdateCheck check) async {
    final release = check.offer.github;
    if (release == null) return;
    final url = release.apkFor(check.abis)?.url;
    await _openInBrowser(url != null && DesktopUpdateInstaller.isTrustedUpdateUrl(url) ? url : release.pageUrl);
  }

  /// Desktop: downloads and installs the GitHub release, the way the start-up prompt does.
  @override
  Future<void> installFromGitHub(UpdateCheck check) async {
    final release = check.offer.github;
    if (release == null) return;
    final asset = release.assets.where((a) => DesktopUpdateInstaller.isPlatformAsset(a.name)).firstOrNull;
    final sums = release.assets.where((a) => a.name == 'SHA256SUMS').firstOrNull;
    if (asset == null || !DesktopUpdateInstaller.isTrustedUpdateUrl(asset.url)) {
      await _openInBrowser(release.pageUrl);
      return;
    }
    await _downloadAndInstall(asset.url, release.tag, sums?.url, asset.name);
  }

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

    final accepted = await showAppUpdateAvailableSheet(
      message:
          'A new version of OpenReader is ready. It downloads in the background, so you can keep reading.',
    );
    if (accepted != true) return;
    await _runPlayUpdate(info);
  }

  /// Google Play's own update: in the background when allowed (then Restart), else the full-screen one.
  Future<void> _runPlayUpdate(AppUpdateInfo info) async {
    try {
      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) _promptRestart();
      } else {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      CustomSnackbar.error(
          'Could not download the update. Try again from Google Play.');
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
    if (latest == null || current == null || _compare(latest, current) <= 0)
      return;

    // Only offer a release that actually has a build for this platform.
    final assets =
        (release['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
    final asset = assets
        .where((a) =>
            DesktopUpdateInstaller.isPlatformAsset(a['name'] as String? ?? ''))
        .firstOrNull;
    final downloadUrl = asset?['browser_download_url'] as String?;
    if (downloadUrl == null) return;
    final sumsUrl = assets
        .where((a) => a['name'] == 'SHA256SUMS')
        .firstOrNull?['browser_download_url'] as String?;

    final accepted = await showAppUpdateAvailableDialog(
      message: 'A new version is ready. It downloads inside the app; '
          'restart when it is ready.',
      version: tag,
      actionLabel: 'Download',
    );
    if (accepted != true) return;

    // An address outside github.com is never fetched: send the user to the
    // release page instead.
    if (!DesktopUpdateInstaller.isTrustedUpdateUrl(downloadUrl)) {
      await _openInBrowser(_releasePageUrl);
      return;
    }
    await _downloadAndInstall(downloadUrl, tag, sumsUrl, asset!['name'] as String);
  }

  void _closeDialog() {
    final context = rootContext;
    if (context != null) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _openInBrowser(String url) async {
    final result = await UrlLauncherService.instance.launch(url);
    result.fold(
        (_) => CustomSnackbar.error('Could not open the download link.'),
        (_) {});
  }

  /// Downloads with a progress sheet, stages the build, then offers Restart.
  Future<void> _downloadAndInstall(
      String url, String tag, String? sumsUrl, String assetName) async {
    final state = ValueNotifier(const UpdateProgress(UpdatePhase.downloading));
    final cancel = UpdateCancelToken();
    var restart = false;
    var browser = false;

    final dialog = showAppUpdateProgress(
      AppUpdateProgress(
        state: state,
        version: tag,
        onCancel: () {
          cancel.cancel();
          _closeDialog();
        },
        onRestart: () {
          restart = true;
          _closeDialog();
        },
        onDownloadInBrowser: () {
          browser = true;
          _closeDialog();
        },
      ),
    );

    String? staged;
    try {
      await DesktopUpdateInstaller.ensureInstallable();
      if (sumsUrl == null) {
        throw UpdateInstallException(
            'This release has no checksum list (SHA256SUMS), so the update was not installed.');
      }
      final sums = await DesktopUpdateInstaller.fetchChecksums(sumsUrl);
      final expected =
          DesktopUpdateInstaller.expectedChecksum(sums, assetName);
      final file = await DesktopUpdateInstaller.download(
        url,
        expectedSha256: expected,
        cancel: cancel,
        onProgress: (p) =>
            state.value = UpdateProgress(UpdatePhase.downloading, progress: p),
      );
      state.value = const UpdateProgress(UpdatePhase.installing);
      staged = await DesktopUpdateInstaller.stage(file);
      state.value = const UpdateProgress(UpdatePhase.ready);
    } on UpdateInstallException catch (e) {
      if (cancel.isCancelled) return;
      state.value = UpdateProgress(UpdatePhase.failed, error: e.message);
    } catch (e) {
      if (cancel.isCancelled) return;
      state.value = const UpdateProgress(UpdatePhase.failed,
          error: 'Could not install the update.');
    }

    await dialog;
    state.dispose();
    if (browser) {
      await _openInBrowser(
          DesktopUpdateInstaller.isTrustedUpdateUrl(url) ? url : _releasePageUrl);
    } else if (restart && staged != null) {
      try {
        await DesktopUpdateInstaller.launchInstallerAndRelaunch(staged);
        exit(0);
      } catch (_) {
        CustomSnackbar.error('Could not restart to finish the update.');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchLatestRelease() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(_latestReleaseUrl));
      // GitHub API rejects requests without a User-Agent (HTTP 403), and
      // Dart's HttpClient sends none by default.
      request.headers.set(HttpHeaders.userAgentHeader,
          'OpenReader/${(await PackageInfo.fromPlatform()).version}');
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok)
        throw HttpException('HTTP ${response.statusCode}');
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static List<int>? _parseVersion(String value) => parseVersion(value);

  static int _compare(List<int> a, List<int> b) => compareVersions(a, b);
}
