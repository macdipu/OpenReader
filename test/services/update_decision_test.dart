import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/services/utilities/update_decision.dart';

GithubRelease release(String tag, {int? build, List<String> apks = const []}) => GithubRelease(
  tag: tag,
  pageUrl: 'https://github.com/macdipu/OpenReader/releases/tag/$tag',
  buildNumber: build,
  assets: [for (final abi in apks) GithubAsset(name: 'openreader-$abi-$tag.apk', url: 'https://github.com/dl/openreader-$abi-$tag.apk')],
);

void main() {
  group('versions', () {
    test('a tag or version is read; anything else is not a version', () {
      expect(parseVersion('v1.2.3'), [1, 2, 3]);
      expect(parseVersion('1.0.23'), [1, 0, 23]);
      expect(parseVersion('  v10.20.30+5 '), [10, 20, 30]);
      expect(parseVersion('build-17'), isNull);
      expect(parseVersion('latest'), isNull);
    });

    test('they compare by number, not by text', () {
      expect(compareVersions([1, 0, 24], [1, 0, 23]), greaterThan(0));
      expect(compareVersions([1, 0, 9], [1, 0, 10]), lessThan(0));
      expect(compareVersions([1, 10, 0], [1, 9, 99]), greaterThan(0));
      expect(compareVersions([2, 0, 0], [1, 99, 99]), greaterThan(0));
      expect(compareVersions([1, 0, 23], [1, 0, 23]), 0);
    });

    test('the build number is read from a Build line in the notes, and only from one', () {
      expect(buildNumberFromNotes('Fixes.\nBuild: 24\nMore.'), 24);
      expect(buildNumberFromNotes('Build number: 7'), 7);
      expect(buildNumberFromNotes('build = 12'), 12);
      expect(buildNumberFromNotes('Rebuilt: 5 times\nThe build is fine'), isNull);
      expect(buildNumberFromNotes(''), isNull);
      expect(buildNumberFromNotes(null), isNull);
    });

    test('the store\'s version is found from the release that has the build it reports', () {
      final releases = [release('v1.0.25', build: 25), release('v1.0.24', build: 24), release('v1.0.22')];
      expect(versionOfBuild(24, releases), [1, 0, 24]);
      expect(versionOfBuild(25, releases), [1, 0, 25]);
      expect(versionOfBuild(23, releases), isNull, reason: 'no release says it is that build');
      expect(versionOfBuild(null, releases), isNull);
    });
  });

  group('the APK for this phone', () {
    final r = release('v1.0.24', apks: ['arm64-v8a', 'armeabi-v7a']);

    test('the first of the phone\'s ABIs that has a build', () {
      expect(r.apkFor(['arm64-v8a', 'armeabi-v7a', 'armeabi'])?.name, 'openreader-arm64-v8a-v1.0.24.apk');
      expect(r.apkFor(['armeabi-v7a', 'armeabi'])?.name, 'openreader-armeabi-v7a-v1.0.24.apk');
      expect(r.apkFor(['arm64-v8a'])?.url, contains('arm64-v8a'));
    });

    test('none when the phone\'s ABIs have no build, or the release has no APK', () {
      expect(r.apkFor(['x86_64', 'x86']), isNull);
      expect(r.apkFor([]), isNull);
      expect(release('v1.0.24').apkFor(['arm64-v8a']), isNull);
      expect(
        const GithubRelease(tag: 'v1', pageUrl: '', assets: [GithubAsset(name: 'openreader-arm64-v8a-v1.aab', url: 'u')]).apkFor(['arm64-v8a']),
        isNull,
        reason: 'a bundle is not an APK',
      );
    });
  });

  group('the store is always the main way; GitHub is a second option only when strictly newer than the store', () {
    const installed = '1.0.23';

    test('up to date everywhere: nothing to offer', () {
      final offer = decideUpdate(installed: installed, store: const StoreStatus(updateAvailable: false), github: release('v1.0.23'));
      expect(offer.upToDate, isTrue);
      expect(offer.storeUpdate, isFalse);
      expect(offer.github, isNull);
    });

    test('GitHub is newer than what the store has (no update there yet): the early build is offered', () {
      final offer = decideUpdate(installed: installed, store: const StoreStatus(updateAvailable: false), github: release('v1.0.24'));
      expect(offer.storeUpdate, isFalse);
      expect(offer.github?.tag, 'v1.0.24');
      expect(offer.githubIsMainSource, isFalse, reason: 'a second option; the store stays the main one');
      expect(offer.upToDate, isFalse);
    });

    test('the store has an update and GitHub has the same version: GitHub is hidden', () {
      final offer = decideUpdate(
        installed: installed,
        store: const StoreStatus(updateAvailable: true, availableBuild: 24, version: [1, 0, 24]),
        github: release('v1.0.24', build: 24),
      );
      expect(offer.storeUpdate, isTrue);
      expect(offer.github, isNull);
    });

    test('the store has an update and GitHub has an even newer one: both, the store first', () {
      final offer = decideUpdate(
        installed: installed,
        store: const StoreStatus(updateAvailable: true, availableBuild: 24, version: [1, 0, 24]),
        github: release('v1.0.25', build: 25),
      );
      expect(offer.storeUpdate, isTrue);
      expect(offer.github?.tag, 'v1.0.25');
      expect(offer.githubIsMainSource, isFalse);
    });

    test('the store is newer than GitHub: GitHub is hidden', () {
      final offer = decideUpdate(
        installed: installed,
        store: const StoreStatus(updateAvailable: true, availableBuild: 26, version: [1, 0, 26]),
        github: release('v1.0.25', build: 25),
      );
      expect(offer.storeUpdate, isTrue);
      expect(offer.github, isNull);
    });

    test('Google Play without a version name: the build numbers decide, and without both GitHub is not claimed ahead', () {
      const play = StoreStatus(updateAvailable: true, availableBuild: 24);
      expect(decideUpdate(installed: installed, store: play, github: release('v1.0.25', build: 25)).github?.tag, 'v1.0.25');
      expect(decideUpdate(installed: installed, store: play, github: release('v1.0.24', build: 24)).github, isNull);
      expect(decideUpdate(installed: installed, store: play, github: release('v1.0.23', build: 23)).github, isNull);
      expect(decideUpdate(installed: installed, store: play, github: release('v1.0.25')).github, isNull, reason: 'GitHub build unknown');
      expect(
        decideUpdate(installed: installed, store: const StoreStatus(updateAvailable: true), github: release('v1.0.25', build: 25)).github,
        isNull,
        reason: 'store build unknown',
      );
    });

    test('an older or equal GitHub release is never offered', () {
      for (final tag in ['v1.0.22', 'v1.0.23', 'v0.9.99']) {
        final offer = decideUpdate(installed: installed, store: const StoreStatus(updateAvailable: false), github: release(tag));
        expect(offer.github, isNull, reason: tag);
        expect(offer.upToDate, isTrue, reason: tag);
      }
    });

    test('GitHub that could not be reached, or a tag that is not a version, adds nothing', () {
      const store = StoreStatus(updateAvailable: false);
      expect(decideUpdate(installed: installed, store: store, github: null).upToDate, isTrue);
      expect(decideUpdate(installed: installed, store: store, github: release('build-17')).github, isNull);
    });

    test('the App Store version decides on its own, with no build numbers', () {
      const store = StoreStatus(updateAvailable: true, version: [1, 0, 24]);
      expect(decideUpdate(installed: installed, store: store, github: release('v1.0.24')).github, isNull);
      expect(decideUpdate(installed: installed, store: store, github: release('v1.0.25')).github?.tag, 'v1.0.25');
      expect(decideUpdate(installed: installed, store: store, github: release('v1.0.23')).github, isNull);
    });
  });

  group('no store to ask (desktop, a sideloaded APK, or the store could not be reached)', () {
    test('GitHub is the main source and is offered when newer than the installed version', () {
      final offer = decideUpdate(installed: '1.0.23', store: null, github: release('v1.0.24'));
      expect(offer.github?.tag, 'v1.0.24');
      expect(offer.githubIsMainSource, isTrue);
      expect(offer.storeUpdate, isFalse);
    });

    test('nothing is offered when GitHub is not newer or could not be fetched', () {
      expect(decideUpdate(installed: '1.0.23', store: null, github: release('v1.0.23')).upToDate, isTrue);
      expect(decideUpdate(installed: '1.0.23', store: null, github: null).upToDate, isTrue);
    });
  });
}
