/// What to show when the user asks for updates (Settings > About > Version).
///
/// The official store is always the main source and its version is the one shown first: Google Play on
/// Android, the App Store on iOS. GitHub never replaces it. When GitHub has a build that is strictly newer
/// than the store's, it is offered as a second option, an early build to try; when the versions match or the
/// store is newer, it is hidden. On desktop there is no store, and GitHub is the way to update.
///
/// Everything here is pure, so each combination can be tested; the versions come from the sources, nothing
/// is written in.

/// One file of a GitHub release.
class GithubAsset {
  const GithubAsset({required this.name, required this.url});

  final String name;
  final String url;
}

/// A GitHub release, as far as an update check needs it.
class GithubRelease {
  const GithubRelease({required this.tag, required this.pageUrl, this.buildNumber, this.assets = const []});

  /// `v1.2.3`.
  final String tag;

  /// The release's page on GitHub.
  final String pageUrl;

  /// The Android build number of that release, when its notes say (`Build: 24`); null when they do not.
  final int? buildNumber;

  /// The files attached to it.
  final List<GithubAsset> assets;

  /// The version in [tag]; null for a tag that is not one.
  List<int>? get version => parseVersion(tag);

  /// The APK for this phone: the first of [abis] (the phone's, best first) that the release has a build
  /// for. Null when none matches, or when there are no APKs.
  GithubAsset? apkFor(List<String> abis) {
    final apks = assets.where((a) => a.name.toLowerCase().endsWith('.apk')).toList();
    for (final abi in abis) {
      for (final apk in apks) {
        if (apk.name.toLowerCase().contains('-${abi.toLowerCase()}-')) return apk;
      }
    }
    return null;
  }
}

/// What the store said when asked.
class StoreStatus {
  const StoreStatus({required this.updateAvailable, this.availableBuild, this.version});

  /// Whether the store has a newer version than the one installed.
  final bool updateAvailable;

  /// The build number the store has, when it says (Google Play does, as a version code).
  final int? availableBuild;

  /// The version the store has, when it is known: the App Store says it, Google Play only gives a build
  /// number, so it is worked out from the release with that build.
  final List<int>? version;
}

/// What to show. [storeUpdate]: the store has a newer version. [github]: a GitHub release to offer; when
/// [githubIsMainSource] it is the only way to update (no store to ask), otherwise it is the second option, an
/// early build that is ahead of the store.
class UpdateOffer {
  const UpdateOffer({required this.storeUpdate, this.github, this.githubIsMainSource = false});

  final bool storeUpdate;
  final GithubRelease? github;
  final bool githubIsMainSource;

  bool get upToDate => !storeUpdate && github == null;
}

/// `v1.2.3` / `1.2.3` -> [1, 2, 3]. Null for anything else, such as the release workflow's `build-<n>` test
/// tags.
List<int>? parseVersion(String value) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(value.trim());
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

/// Negative when [a] is older than [b], positive when newer, 0 when equal.
int compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// The build number in a release's notes, from a line like `Build: 24` or `Build number: 24`; null when
/// there is none.
int? buildNumberFromNotes(String? notes) {
  if (notes == null) return null;
  final match = RegExp(r'^\s*build(?:\s+number)?\s*[:=]\s*(\d+)\s*$', caseSensitive: false, multiLine: true).firstMatch(notes);
  return match == null ? null : int.parse(match.group(1)!);
}

/// The version of the newest of [releases] that has [build], so a store that only gives a build number
/// (Google Play) can still be shown with a version. Null when none says it is that build.
List<int>? versionOfBuild(int? build, List<GithubRelease> releases) {
  if (build == null) return null;
  for (final release in releases) {
    if (release.buildNumber == build) return release.version;
  }
  return null;
}

/// Decides what to offer.
///
/// [installed] is the version installed (`1.0.23`). [store] is what the store said, or null when there is no
/// store to ask (a desktop app, an Android build that was not installed from Google Play, or a store that could
/// not be reached). [github] is the newest release, or null when it could not be fetched.
///
/// With a store, GitHub is offered only when it is strictly newer than the store's version:
/// - the store's version is [StoreStatus.version], or the installed one when the store has no update;
/// - when that is not known (Google Play with an update and no matching release), the build numbers decide,
///   and without both of them GitHub is not claimed to be ahead.
/// An equal or older GitHub release is never shown.
///
/// With no store, GitHub is the only source, offered when newer than the installed version.
UpdateOffer decideUpdate({required String installed, required StoreStatus? store, required GithubRelease? github}) {
  final current = parseVersion(installed);
  final latest = github?.version;

  if (store == null) {
    final newer = github != null && current != null && latest != null && compareVersions(latest, current) > 0;
    return UpdateOffer(storeUpdate: false, github: newer ? github : null, githubIsMainSource: true);
  }

  // What the store has: its own version, or what is installed when it has nothing newer.
  final storeVersion = store.version ?? (store.updateAvailable ? null : current);
  final bool ahead;
  if (github == null) {
    ahead = false;
  } else if (storeVersion != null && latest != null) {
    ahead = compareVersions(latest, storeVersion) > 0;
  } else if (github.buildNumber != null && store.availableBuild != null) {
    ahead = github.buildNumber! > store.availableBuild!;
  } else {
    ahead = false;
  }
  return UpdateOffer(storeUpdate: store.updateAvailable, github: ahead ? github : null);
}
