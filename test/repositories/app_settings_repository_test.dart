import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/data/repositories/app_settings_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppSettingsRepositoryImpl repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = AppSettingsRepositoryImpl();
  });

  test('new settings have their defaults when never set', () async {
    expect(await repo.getRestoreReadingPosition(), isTrue);
    expect(await repo.getCacheCapMb(), isNull);
    expect(await repo.getHistoryRetentionDays(), isNull);
  });

  test('values round-trip and use the app_settings: prefix', () async {
    await repo.setRestoreReadingPosition(false);
    await repo.setCacheCapMb(256);
    await repo.setHistoryRetentionDays(0);

    expect(await repo.getRestoreReadingPosition(), isFalse);
    expect(await repo.getCacheCapMb(), 256);
    expect(await repo.getHistoryRetentionDays(), 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), everyElement(startsWith('app_settings:')));
    expect(prefs.getKeys(), hasLength(3));
  });

  test('setting null removes the cap and the retention', () async {
    await repo.setCacheCapMb(64);
    await repo.setHistoryRetentionDays(30);
    await repo.setCacheCapMb(null);
    await repo.setHistoryRetentionDays(null);
    expect(await repo.getCacheCapMb(), isNull);
    expect(await repo.getHistoryRetentionDays(), isNull);
  });

  test('clearSettings removes the new keys and restores defaults', () async {
    await repo.setRestoreReadingPosition(false);
    await repo.setCacheCapMb(256);
    await repo.setHistoryRetentionDays(7);

    await repo.clearSettings();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(await repo.getRestoreReadingPosition(), isTrue);
    expect(await repo.getCacheCapMb(), isNull);
    expect(await repo.getHistoryRetentionDays(), isNull);
  });

  test('clearPreferencesKeepingSetup resets preferences and keeps the setup flags', () async {
    await repo.setOnboardingComplete(true);
    await repo.setAutoScanned(true);
    await repo.setCacheCapMb(64);
    await repo.clearPreferencesKeepingSetup();
    expect(await repo.hasCompletedOnboarding(), isTrue);
    expect(await repo.hasAutoScanned(), isTrue);
    expect(await repo.getCacheCapMb(), isNull);
    await repo.clearSettings();
    expect(await repo.hasCompletedOnboarding(), isFalse);
    expect(await repo.hasAutoScanned(), isFalse);
  });

  test('hide thumbnails: default off, round-trips, removed by both clears', () async {
    expect(await repo.getHideThumbnails(), isFalse);
    await repo.setHideThumbnails(true);
    expect(await repo.getHideThumbnails(), isTrue);
    expect((await SharedPreferences.getInstance()).getKeys(), everyElement(startsWith('app_settings:')));
    await repo.clearPreferencesKeepingSetup();
    expect(await repo.getHideThumbnails(), isFalse);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    await repo.setHideThumbnails(true);
    await repo.clearSettings();
    expect(await repo.getHideThumbnails(), isFalse);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
