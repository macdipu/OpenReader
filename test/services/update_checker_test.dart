import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:openreader/services/utilities/update_checker.dart';
import 'package:package_info_plus/package_info_plus.dart';

String releases(List<Map<String, Object?>> list) => jsonEncode(list);

Map<String, Object?> rel(String tag, {int? build, bool draft = false, bool prerelease = false, List<String> apks = const ['arm64-v8a']}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/macdipu/OpenReader/releases/tag/$tag',
  'draft': draft,
  'prerelease': prerelease,
  'body': build == null ? 'Notes' : 'Build: $build\n\nNotes',
  'assets': [
    for (final abi in apks) {'name': 'openreader-$abi-$tag.apk', 'browser_download_url': 'https://github.com/macdipu/OpenReader/releases/download/$tag/openreader-$abi-$tag.apk'},
  ],
};

AppUpdateInfo play({required bool available, int? code}) => AppUpdateInfo(
  updateAvailability: available ? UpdateAvailability.updateAvailable : UpdateAvailability.updateNotAvailable,
  immediateUpdateAllowed: true,
  immediateAllowedPreconditions: null,
  flexibleUpdateAllowed: true,
  flexibleAllowedPreconditions: null,
  availableVersionCode: code,
  installStatus: InstallStatus.unknown,
  packageName: 'p',
  clientVersionStalenessDays: null,
  updatePriority: 0,
);

UpdateChecker checker({
  required UpdatePlatform platform,
  String github = '[]',
  bool githubFails = false,
  AppUpdateInfo? playInfo,
  bool playFails = false,
  String itunes = '{"resultCount":0,"results":[]}',
  bool itunesFails = false,
  String version = '1.0.23',
}) => UpdateChecker(
  platform: platform,
  packageInfo: () async => PackageInfo(appName: 'OpenReader', packageName: 'p', version: version, buildNumber: '23'),
  fetch: (uri) async {
    if (uri.host == 'api.github.com') {
      if (githubFails) throw Exception('offline');
      return github;
    }
    if (uri.host == 'itunes.apple.com') {
      if (itunesFails) throw Exception('offline');
      return itunes;
    }
    throw StateError('unexpected ${uri.host}');
  },
  playCheck: () async {
    if (playFails) throw Exception('not from Play');
    return playInfo ?? play(available: false);
  },
  abis: () async => ['arm64-v8a', 'armeabi-v7a'],
);

void main() {
  group('reading GitHub\'s releases', () {
    test('newest first; drafts, pre-releases and tags that are not versions are left out; the build comes from the notes', () {
      final parsed = UpdateChecker.parseReleases(releases([
        rel('v1.0.25', draft: true),
        rel('v1.0.24', build: 24),
        rel('build-9'),
        rel('v1.0.24-rc1', prerelease: true),
        rel('v1.0.23', build: 23),
      ]));
      expect(parsed.map((r) => r.tag), ['v1.0.24', 'v1.0.23']);
      expect(parsed.first.buildNumber, 24);
      expect(parsed.first.apkFor(['arm64-v8a'])?.url, endsWith('openreader-arm64-v8a-v1.0.24.apk'));
      expect(parsed.first.pageUrl, endsWith('/tag/v1.0.24'));
    });

    test('anything unexpected is no releases, not a crash', () {
      expect(UpdateChecker.parseReleases('{}'), isEmpty);
      expect(UpdateChecker.parseReleases('[]'), isEmpty);
      expect(UpdateChecker.parseReleases(jsonEncode([1, 'x', {'tag_name': 5}])), isEmpty);
    });
  });

  group('reading the App Store lookup', () {
    test('the version and the page', () {
      final found = UpdateChecker.parseItunes('{"resultCount":1,"results":[{"version":"1.0.24","trackViewUrl":"https://apps.apple.com/app/id1"}]}');
      expect(found?.version, [1, 0, 24]);
      expect(found?.url, 'https://apps.apple.com/app/id1');
    });

    test('an app that is not there, or a reply that is not one, is null', () {
      expect(UpdateChecker.parseItunes('{"resultCount":0,"results":[]}'), isNull);
      expect(UpdateChecker.parseItunes('[]'), isNull);
      expect(UpdateChecker.parseItunes('{"results":[{"version":"beta"}]}'), isNull);
    });
  });

  group('Android: Google Play first, GitHub a second option only when newer than Play', () {
    test('up to date on Play, GitHub newer: the early build is offered, the store stays the main one', () async {
      final result = await checker(platform: UpdatePlatform.android, github: releases([rel('v1.0.24', build: 24)])).check();
      expect(result.storeName, 'Google Play');
      expect(result.storeVersionLabel, 'v1.0.23');
      expect(result.offer.storeUpdate, isFalse);
      expect(result.offer.github?.tag, 'v1.0.24');
      expect(result.offer.githubIsMainSource, isFalse);
      expect(result.abis, ['arm64-v8a', 'armeabi-v7a']);
      expect(result.summary, contains('early build v1.0.24'));
    });

    test('Play has an update and GitHub has the same one: only the store, shown with its version name', () async {
      final result = await checker(
        platform: UpdatePlatform.android,
        playInfo: play(available: true, code: 24),
        github: releases([rel('v1.0.24', build: 24), rel('v1.0.23', build: 23)]),
      ).check();
      expect(result.offer.storeUpdate, isTrue);
      expect(result.storeVersionLabel, 'v1.0.24', reason: 'the release with Play\'s build says which version it is');
      expect(result.offer.github, isNull);
      expect(result.summary, startsWith('Google Play has v1.0.24'));
    });

    test('Play has an update and GitHub has a newer one: both', () async {
      final result = await checker(
        platform: UpdatePlatform.android,
        playInfo: play(available: true, code: 24),
        github: releases([rel('v1.0.25', build: 25), rel('v1.0.24', build: 24)]),
      ).check();
      expect(result.offer.storeUpdate, isTrue);
      expect(result.storeVersionLabel, 'v1.0.24');
      expect(result.offer.github?.tag, 'v1.0.25');
    });

    test('Play\'s build is shown as a build when no release says which version it is', () async {
      final result = await checker(platform: UpdatePlatform.android, playInfo: play(available: true, code: 24), github: releases([rel('v1.0.23')])).check();
      expect(result.storeVersionLabel, 'build 24');
      expect(result.offer.github, isNull);
    });

    test('everything the same: up to date', () async {
      final result = await checker(platform: UpdatePlatform.android, github: releases([rel('v1.0.23', build: 23)])).check();
      expect(result.offer.upToDate, isTrue);
      expect(result.summary, 'Up to date');
    });

    test('Google Play unreachable (or not installed from Play): GitHub is the main source', () async {
      final result = await checker(platform: UpdatePlatform.android, playFails: true, github: releases([rel('v1.0.24', build: 24)])).check();
      expect(result.storeUnreachable, isTrue);
      expect(result.offer.githubIsMainSource, isTrue);
      expect(result.offer.github?.tag, 'v1.0.24');
    });

    test('GitHub unreachable: the store alone answers, no early build', () async {
      final result = await checker(platform: UpdatePlatform.android, githubFails: true, playInfo: play(available: true, code: 24)).check();
      expect(result.githubUnreachable, isTrue);
      expect(result.offer.storeUpdate, isTrue);
      expect(result.offer.github, isNull);
      expect(result.failed, isFalse);
    });

    test('both unreachable: it could not check', () async {
      final result = await checker(platform: UpdatePlatform.android, playFails: true, githubFails: true).check();
      expect(result.failed, isTrue);
      expect(result.summary, 'Could not check for updates');
    });
  });

  group('iOS: the App Store only', () {
    const itunes = '{"resultCount":1,"results":[{"version":"1.0.24","trackViewUrl":"https://apps.apple.com/app/id1"}]}';

    test('a newer App Store version is the update, with its version and page', () async {
      final result = await checker(platform: UpdatePlatform.ios, itunes: itunes).check();
      expect(result.storeName, 'App Store');
      expect(result.offer.storeUpdate, isTrue);
      expect(result.storeVersionLabel, 'v1.0.24');
      expect(result.storeUrl, 'https://apps.apple.com/app/id1');
    });

    test('GitHub is never asked, since iOS cannot install an early build', () async {
      var asked = false;
      final c = UpdateChecker(
        platform: UpdatePlatform.ios,
        packageInfo: () async => PackageInfo(appName: 'a', packageName: 'p', version: '1.0.23', buildNumber: '23'),
        fetch: (uri) async {
          if (uri.host == 'api.github.com') asked = true;
          return itunes;
        },
      );
      final result = await c.check();
      expect(asked, isFalse);
      expect(result.offer.github, isNull);
    });

    test('up to date, not found on the App Store, or unreachable', () async {
      expect((await checker(platform: UpdatePlatform.ios, itunes: itunes, version: '1.0.24').check()).offer.upToDate, isTrue);
      final missing = await checker(platform: UpdatePlatform.ios).check();
      expect(missing.storeUnreachable, isTrue);
      expect(missing.failed, isTrue);
      expect((await checker(platform: UpdatePlatform.ios, itunesFails: true).check()).failed, isTrue);
    });
  });

  group('desktop: GitHub only', () {
    test('a newer release is the update', () async {
      final result = await checker(platform: UpdatePlatform.desktop, github: releases([rel('v1.0.24')])).check();
      expect(result.storeName, isNull);
      expect(result.offer.githubIsMainSource, isTrue);
      expect(result.offer.github?.tag, 'v1.0.24');
      expect(result.summary, 'v1.0.24 is available');
    });

    test('up to date, and unreachable', () async {
      expect((await checker(platform: UpdatePlatform.desktop, github: releases([rel('v1.0.23')])).check()).summary, 'Up to date');
      expect((await checker(platform: UpdatePlatform.desktop, githubFails: true).check()).failed, isTrue);
    });
  });

  test('a platform with nothing to check answers up to date without asking anyone', () async {
    final result = await checker(platform: UpdatePlatform.none, githubFails: true).check();
    expect(result.offer.upToDate, isTrue);
    expect(result.failed, isFalse);
    expect(result.summary, '');
  });
}
