import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/presentation/utils/platform_info.dart';
import 'update_decision.dart';

/// Where the app runs, for what an update check can ask.
enum UpdatePlatform {
  /// Google Play is the store; GitHub has early builds.
  android,

  /// The App Store is the store; there is no early build (iOS cannot install one).
  ios,

  /// No store: GitHub releases are how the app updates.
  desktop,

  /// Nothing to check.
  none;

  static UpdatePlatform get current {
    if (PlatformInfo.isAndroid) return android;
    if (PlatformInfo.isIOS) return ios;
    if (PlatformInfo.isDesktop) return desktop;
    return none;
  }
}

/// The answer to "is there an update?" (Settings > About > Version).
class UpdateCheck {
  const UpdateCheck({
    required this.installed,
    required this.platform,
    required this.offer,
    this.storeName,
    this.store,
    this.storeVersionLabel,
    this.storeUnreachable = false,
    this.latest,
    this.githubUnreachable = false,
    this.playInfo,
    this.storeUrl,
    this.abis = const [],
  });

  /// The version installed (`1.0.23`).
  final String installed;
  final UpdatePlatform platform;

  /// What to offer.
  final UpdateOffer offer;

  /// "Google Play" or "App Store"; null where there is no store.
  final String? storeName;

  /// What the store said; null when there is no store or it could not be reached.
  final StoreStatus? store;

  /// The store's version as shown: `v1.0.24`, or `build 24` when only the build is known.
  final String? storeVersionLabel;

  /// The store could not be asked (offline, or an Android build that did not come from Google Play).
  final bool storeUnreachable;

  /// The newest GitHub release, when it could be fetched.
  final GithubRelease? latest;
  final bool githubUnreachable;

  /// Google Play's answer, for starting its update.
  final AppUpdateInfo? playInfo;

  /// The store page to open (the App Store's).
  final String? storeUrl;

  /// The phone's CPU types, best first, to pick the early build's APK.
  final List<String> abis;

  /// Nothing could be asked at all.
  bool get failed => switch (platform) {
    UpdatePlatform.android => storeUnreachable && githubUnreachable,
    UpdatePlatform.ios => storeUnreachable,
    UpdatePlatform.desktop => githubUnreachable,
    UpdatePlatform.none => false,
  };

  /// One line for the Version row.
  String get summary {
    final early = offer.github;
    if (platform == UpdatePlatform.none) return '';
    if (failed) return 'Could not check for updates';
    if (offer.githubIsMainSource) {
      return early == null ? 'Up to date' : '${early.tag} is available';
    }
    final store = offer.storeUpdate ? '${storeName ?? 'The store'} has ${storeVersionLabel ?? 'an update'}' : 'Up to date';
    return early == null ? store : '$store · early build ${early.tag} on GitHub';
  }
}

/// What the buttons of the update sheet do.
abstract class UpdateActions {
  /// Starts the store's own update (Google Play's in-app update).
  Future<void> startStoreUpdate(UpdateCheck check);

  /// Opens the store's page for the app.
  Future<void> openStore(UpdateCheck check);

  /// Downloads the GitHub early build's APK for this phone (or opens its release page).
  Future<void> downloadEarlyBuild(UpdateCheck check);

  /// Downloads and installs the GitHub release (desktop).
  Future<void> installFromGitHub(UpdateCheck check);
}

typedef _Fetch = Future<String> Function(Uri uri);

/// Asks the store and GitHub what is newest. Nothing is sent but the request itself: no account, no device
/// identifier.
class UpdateChecker {
  UpdateChecker({
    _Fetch? fetch,
    Future<PackageInfo> Function()? packageInfo,
    Future<AppUpdateInfo> Function()? playCheck,
    Future<List<String>> Function()? abis,
    UpdatePlatform? platform,
  }) : _fetch = fetch ?? _get,
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _playCheck = playCheck ?? InAppUpdate.checkForUpdate,
       _abis = abis ?? _deviceAbis,
       _platform = platform;

  static const githubReleasesUrl = 'https://api.github.com/repos/macdipu/OpenReader/releases?per_page=15';
  static const bundleId = 'com.chowdhuryelab.openreader';

  final _Fetch _fetch;
  final Future<PackageInfo> Function() _packageInfo;
  final Future<AppUpdateInfo> Function() _playCheck;
  final Future<List<String>> Function() _abis;
  final UpdatePlatform? _platform;

  Future<UpdateCheck> check() async {
    final platform = _platform ?? UpdatePlatform.current;
    final info = await _packageInfo();
    final installed = info.version;
    if (platform == UpdatePlatform.none) {
      return UpdateCheck(installed: installed, platform: platform, offer: const UpdateOffer(storeUpdate: false));
    }

    // GitHub: the releases, newest first. iOS cannot install an early build, so it does not ask.
    var releases = <GithubRelease>[];
    var githubUnreachable = false;
    if (platform != UpdatePlatform.ios) {
      try {
        releases = parseReleases(await _fetch(Uri.parse(githubReleasesUrl)));
      } catch (_) {
        githubUnreachable = true;
      }
    }
    final latest = releases.isEmpty ? null : releases.first;

    StoreStatus? store;
    String? storeName;
    String? storeVersionLabel;
    String? storeUrl;
    AppUpdateInfo? playInfo;
    var storeUnreachable = false;

    switch (platform) {
      case UpdatePlatform.android:
        storeName = 'Google Play';
        try {
          final play = await _playCheck();
          playInfo = play;
          final available = play.updateAvailability == UpdateAvailability.updateAvailable;
          final build = available ? play.availableVersionCode : null;
          // Google Play gives a build number, not a version: the release with that build says which version.
          final version = available ? versionOfBuild(build, releases) : null;
          store = StoreStatus(updateAvailable: available, availableBuild: build, version: version);
          storeVersionLabel = !available
              ? 'v$installed'
              : version != null
              ? 'v${version.join('.')}'
              : (build != null ? 'build $build' : null);
        } catch (_) {
          storeUnreachable = true;
        }
      case UpdatePlatform.ios:
        storeName = 'App Store';
        try {
          final found = parseItunes(await _fetch(Uri.parse('https://itunes.apple.com/lookup?bundleId=$bundleId')));
          if (found == null) {
            storeUnreachable = true;
          } else {
            final current = parseVersion(installed);
            final available = current != null && compareVersions(found.version, current) > 0;
            store = StoreStatus(updateAvailable: available, version: found.version);
            storeVersionLabel = 'v${found.version.join('.')}';
            storeUrl = found.url;
          }
        } catch (_) {
          storeUnreachable = true;
        }
      case UpdatePlatform.desktop || UpdatePlatform.none:
        break;
    }

    final offer = decideUpdate(installed: installed, store: store, github: platform == UpdatePlatform.ios ? null : latest);
    return UpdateCheck(
      installed: installed,
      platform: platform,
      offer: offer,
      storeName: storeName,
      store: store,
      storeVersionLabel: storeVersionLabel,
      storeUnreachable: storeUnreachable,
      latest: latest,
      githubUnreachable: githubUnreachable,
      playInfo: playInfo,
      storeUrl: storeUrl,
      abis: platform == UpdatePlatform.android ? await _abis() : const [],
    );
  }

  /// GitHub's list of releases as [GithubRelease]s, newest first, without drafts, pre-releases and tags that
  /// are not versions.
  static List<GithubRelease> parseReleases(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    final releases = <GithubRelease>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      if (item['draft'] == true || item['prerelease'] == true) continue;
      final tag = item['tag_name'];
      if (tag is! String || parseVersion(tag) == null) continue;
      final assets = <GithubAsset>[
        for (final asset in (item['assets'] as List? ?? const []))
          if (asset is Map && asset['name'] is String && asset['browser_download_url'] is String)
            GithubAsset(name: asset['name'] as String, url: asset['browser_download_url'] as String),
      ];
      releases.add(
        GithubRelease(
          tag: tag,
          pageUrl: (item['html_url'] as String?) ?? 'https://github.com/macdipu/OpenReader/releases/tag/$tag',
          buildNumber: buildNumberFromNotes(item['body'] as String?),
          assets: assets,
        ),
      );
    }
    return releases;
  }

  /// The App Store lookup's version and page; null when the app is not found there.
  static ({List<int> version, String? url})? parseItunes(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return null;
    final results = decoded['results'];
    if (results is! List || results.isEmpty || results.first is! Map) return null;
    final first = results.first as Map;
    final version = first['version'] is String ? parseVersion(first['version'] as String) : null;
    if (version == null) return null;
    return (version: version, url: first['trackViewUrl'] as String?);
  }

  static Future<String> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      // GitHub rejects a request without a User-Agent (HTTP 403); a generic one, no device identifier.
      request.headers.set(HttpHeaders.userAgentHeader, 'OpenReader');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}');
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  /// The phone's CPU types, best first (Android); the 64-bit ARM build when it cannot be read.
  static Future<List<String>> _deviceAbis() async {
    try {
      final abis = await const MethodChannel('openreader/device').invokeMethod<List<Object?>>('abis');
      final list = [for (final abi in abis ?? const []) abi.toString()];
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return const ['arm64-v8a'];
  }
}
