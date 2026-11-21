import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/dynamic_color_preferences.dart';
import '../../../core/presentation/controllers/reader_preferences.dart';
import '../../../core/presentation/controllers/reader_wakelock.dart';
import '../../../core/presentation/controllers/theme_controller.dart';
import '../../../core/presentation/controllers/thumbnail_preferences.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/platform_info.dart';
import '../../../core/presentation/widgets/show_dialog/confirm_dialog.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/platform_integration/default_app_service.dart';
import '../../../services/utilities/path_service.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../../../services/utilities/url_launcher_service.dart';
import '../../home/presentation/home_controller.dart';
import '../../recents/presentation/recents_controller.dart';
import '../../text_reader/presentation/text_reader_controller.dart';
import 'settings_maintenance.dart';

/// Settings screen (BRD 9.18, DESIGN_SPEC.md #01).
///
/// Every preference lives in [AppSettingsRepository] (the readers read it when they open and write
/// it from their toolbars); this controller mirrors it for the screen and [reload]s whenever
/// Settings comes into view, so both sides show the same value. Theme stays with [ThemeController].
class SettingsController extends GetxController with WidgetsBindingObserver {
  final PathService _pathService;
  final AppSettingsRepository _settings;
  final RecentRepository _recents;
  final StorageAccessService _storageAccess;
  final DefaultAppService _defaultApp;
  final Future<void> Function(String text) _share;
  final ThemeController? _theme;
  final Future<bool> Function(String url) _openUrl;

  SettingsController({
    PathService? pathService,
    AppSettingsRepository? settings,
    RecentRepository? recents,
    StorageAccessService? storageAccess,
    DefaultAppService? defaultApp,
    Future<void> Function(String text)? share,
    ThemeController? themeController,
    Future<bool> Function(String url)? openUrl,
  })  : _pathService = pathService ?? PathService.instance,
        _settings = settings ?? AppSettingsRepositoryImpl(),
        _recents = recents ?? RecentRepositoryImpl(),
        _storageAccess = storageAccess ?? StorageAccessService.instance,
        _defaultApp = defaultApp ?? DefaultAppService.instance,
        _share = share ?? _sharePlain,
        _theme = themeController,
        _openUrl = openUrl ?? _launchUrl;

  static Future<void> _sharePlain(String text) async {
    await SharePlus.instance.share(ShareParams(text: text, title: 'OpenReader'));
  }

  static Future<bool> _launchUrl(String url) async =>
      (await UrlLauncherService.instance.launch(url)).isRight();

  /// OpenReader's Play Store page: where Rate app goes and what Share app links to.
  static const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader';

  /// Rate app needs a store page; only the Android one is known (no iOS or desktop store URL).
  static bool get canRateApp => PlatformInfo.isAndroid;

  ThemeController get themeController => _theme ?? Get.find<ThemeController>();

  /// Cache cap choices in MB (null = no cap) and history retention choices in days (null =
  /// forever, 0 = off).
  static const cacheCapChoices = <int?>[null, 100, 500, 1024];
  static const retentionChoices = <int?>[null, 30, 0];

  final appVersion = ''.obs;

  /// Real cache size for the Cache card - never fabricated.
  final cacheSizeBytes = 0.obs;
  final isLoadingStats = true.obs;

  // Reading
  final pdfContinuous = true.obs;
  final nightMode = false.obs;
  final fontSize = TextReaderController.defaultFontSize.obs;
  final lineWrap = true.obs;
  final restorePosition = true.obs;
  final hideThumbnails = false.obs;
  final keepScreenAwake = false.obs;

  // Appearance
  final useDynamicColor = false.obs;

  /// Whether the system offers a dynamic palette (ST-20); the switch is hidden when it doesn't.
  bool get dynamicColorAvailable => DynamicColorPreferences.available;

  // Files & storage
  final cacheCapMb = Rxn<int>();
  final historyRetentionDays = Rxn<int>();

  /// Android file access; null until read, or when it cannot be read (nothing is shown then).
  final storageState = Rxn<StorageAccessState>();

  /// Per-type default-app status. Types the platform could not read are [DefaultStatus.unknown]
  /// and show no status.
  final defaultStatuses = <DocumentType, DefaultStatus>{}.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // A reader toolbar (or another Settings pane) changed a reading preference: show it now.
    _preferenceSync = ReaderPreferences.changes.listen(_onPreferenceChanged);
    _loadAppVersion();
    unawaited(reload());
  }

  StreamSubscription<ReaderPreferenceChange>? _preferenceSync;
  Timer? _delayedDefaultsRefresh;
  final _permissionRechecks = <Timer>[];

  /// After the OS permission page, the state can lag behind the user's choice: re-check this long
  /// after returning, until it differs from what it was before leaving.
  static const permissionRecheckDelays = [
    Duration(milliseconds: 700),
    Duration(milliseconds: 1500),
    Duration(seconds: 3),
  ];

  void _onPreferenceChanged(ReaderPreferenceChange change) {
    final value = change.value;
    switch (change.preference) {
      case ReaderPreference.nightMode:
        if (value is bool) nightMode.value = value;
      case ReaderPreference.pdfContinuous:
        if (value is bool) pdfContinuous.value = value;
      case ReaderPreference.lineWrap:
        if (value is bool) lineWrap.value = value;
      case ReaderPreference.fontSize:
        if (value is double) {
          fontSize.value = value.clamp(TextReaderController.minFontSize, TextReaderController.maxFontSize);
        }
    }
  }

  @override
  void onClose() {
    unawaited(_preferenceSync?.cancel());
    _delayedDefaultsRefresh?.cancel();
    _cancelPermissionRechecks();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Permissions and default apps can change in the OS settings while the app is away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(watchPermissions(storageState.value));
      unawaited(refreshDefaults());
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = '${info.version} (${info.buildNumber})';
    } catch (_) {}
  }

  /// Re-reads every preference and the platform status, then applies the cache cap and the
  /// history retention. Called when Settings is shown.
  Future<void> reload() async {
    await _loadPreferences();
    unawaited(refreshPermissions());
    unawaited(refreshDefaults());
    if (await enforceHistoryRetention(settings: _settings, recents: _recents)) _refreshHistoryViews();
    await _applyCacheCap();
    await _loadStats();
  }

  Future<void> _loadPreferences() async {
    Future<void> read(Future<void> Function() body) async {
      try {
        await body();
      } catch (_) {
        // A preference that cannot be read keeps its last shown value.
      }
    }

    await read(() async => pdfContinuous.value = await _settings.getDefaultContinuousScroll());
    await read(() async => nightMode.value = await _settings.getReaderNightMode() ?? false);
    await read(() async {
      final size = await _settings.getTextReaderFontSize();
      fontSize.value = (size ?? TextReaderController.defaultFontSize)
          .clamp(TextReaderController.minFontSize, TextReaderController.maxFontSize);
    });
    await read(() async => lineWrap.value = await _settings.getTextReaderLineWrap() ?? true);
    await read(() async => restorePosition.value = await _settings.getRestoreReadingPosition());
    await read(() async {
      hideThumbnails.value = await _settings.getHideThumbnails();
      ThumbnailPreferences.hidden.value = hideThumbnails.value;
    });
    await read(() async {
      keepScreenAwake.value = await _settings.getKeepScreenAwake();
      ReaderWakelock.keepAwake.value = keepScreenAwake.value;
    });
    await read(() async {
      useDynamicColor.value = await _settings.getUseDynamicColor();
      DynamicColorPreferences.enabled.value = useDynamicColor.value;
    });
    await read(() async => cacheCapMb.value = await _settings.getCacheCapMb());
    await read(() async => historyRetentionDays.value = await _settings.getHistoryRetentionDays());
  }

  // ---- Reading ----

  Future<void> setPdfContinuous(bool value) async {
    pdfContinuous.value = value;
    await _guard(() => _settings.setDefaultContinuousScroll(value));
    ReaderPreferences.publish(ReaderPreference.pdfContinuous, value);
  }

  Future<void> setNightMode(bool value) async {
    nightMode.value = value;
    await _guard(() => _settings.setReaderNightMode(value));
    ReaderPreferences.publish(ReaderPreference.nightMode, value);
  }

  Future<void> setFontSize(double value) async {
    final size = value.clamp(TextReaderController.minFontSize, TextReaderController.maxFontSize);
    fontSize.value = size;
    await _guard(() => _settings.setTextReaderFontSize(size));
    ReaderPreferences.publish(ReaderPreference.fontSize, size);
  }

  Future<void> increaseFontSize() => setFontSize(fontSize.value + 2);
  Future<void> decreaseFontSize() => setFontSize(fontSize.value - 2);
  bool get canIncreaseFontSize => fontSize.value < TextReaderController.maxFontSize;
  bool get canDecreaseFontSize => fontSize.value > TextReaderController.minFontSize;

  Future<void> setLineWrap(bool value) async {
    lineWrap.value = value;
    await _guard(() => _settings.setTextReaderLineWrap(value));
    ReaderPreferences.publish(ReaderPreference.lineWrap, value);
  }

  Future<void> setRestorePosition(bool value) async {
    restorePosition.value = value;
    await _guard(() => _settings.setRestoreReadingPosition(value));
  }

  Future<void> setHideThumbnails(bool value) async {
    hideThumbnails.value = value;
    ThumbnailPreferences.hidden.value = value;
    await _guard(() => _settings.setHideThumbnails(value));
  }

  /// Keep the screen awake while a reader is visible (ST-16); takes effect at once in an open reader.
  Future<void> setKeepScreenAwake(bool value) async {
    keepScreenAwake.value = value;
    ReaderWakelock.keepAwake.value = value;
    await _guard(() => _settings.setKeepScreenAwake(value));
  }

  // ---- Appearance ----

  /// Use wallpaper / accent colours (ST-20); the theme rebuilds at once.
  Future<void> setUseDynamicColor(bool value) async {
    useDynamicColor.value = value;
    DynamicColorPreferences.enabled.value = value;
    await _guard(() => _settings.setUseDynamicColor(value));
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (_) {
      // Preferences are a convenience; the screen keeps working.
    }
  }

  // ---- Permissions (Android) ----

  Future<void> refreshPermissions() async {
    try {
      final state = await _storageAccess.state();
      storageState.value = state == StorageAccessState.notApplicable ? null : state;
    } catch (_) {
      storageState.value = null;
    }
  }

  void _cancelPermissionRechecks() {
    for (final timer in _permissionRechecks) {
      timer.cancel();
    }
    _permissionRechecks.clear();
  }

  /// Refreshes now, then again after each of [permissionRecheckDelays], stopping as soon as the state
  /// differs from [before] (the state shown before the user left for the OS page) or the controller
  /// closes. A grant can reach the app a moment after it returns to the foreground.
  Future<void> watchPermissions(StorageAccessState? before) async {
    _cancelPermissionRechecks();
    for (final delay in permissionRecheckDelays) {
      late final Timer timer;
      timer = Timer(delay, () async {
        _permissionRechecks.remove(timer);
        if (isClosed || storageState.value != before) return;
        await refreshPermissions();
        if (storageState.value != before) _cancelPermissionRechecks();
      });
      _permissionRechecks.add(timer);
    }
    await refreshPermissions();
    if (storageState.value != before) _cancelPermissionRechecks();
  }

  /// The action that matches the state: open the All files access page (Android 11+) or ask (older
  /// Android) when not allowed, explain and open the page when blocked, open the app's settings to
  /// revoke when allowed.
  Future<void> fixStorageAccess() async {
    final before = storageState.value;
    switch (storageState.value) {
      case StorageAccessState.notAllowed:
        await _storageAccess.requestOrOpenSettings();
      case StorageAccessState.blocked:
        final open = await showConfirmDialog(
          title: 'Allow file access in settings',
          message: 'Android no longer shows the permission prompt. We will open the "All files access" '
              'page: turn on the switch for OpenReader, then come back.',
          confirmLabel: 'Open page',
        );
        if (open) await _storageAccess.openAllFilesAccessSettings();
      case StorageAccessState.allowed:
        await _storageAccess.openSettings();
      case StorageAccessState.notApplicable:
      case null:
        break;
    }
    await watchPermissions(before);
  }

  /// The "How to allow it" help: straight to the All files access page.
  Future<void> openAllFilesAccess() async {
    final before = storageState.value;
    await _storageAccess.openAllFilesAccessSettings();
    await watchPermissions(before);
  }

  /// iOS: the app's page in the system Settings.
  Future<void> openAppPermissions() async {
    await _storageAccess.openSettings();
  }

  // ---- File handling (desktop) ----

  Future<void> refreshDefaults() async {
    if (!_defaultApp.isSupported) return;
    try {
      defaultStatuses.assignAll(await _defaultApp.queryDefaults());
    } catch (_) {
      defaultStatuses.clear();
    }
  }

  Future<void> makeDefault(Set<DocumentType> types) async {
    final result = await _defaultApp.makeDefault(types);
    if (result.success) {
      CustomSnackbar.success(result.message);
    } else {
      CustomSnackbar.error(result.message);
    }
    await refreshDefaults();
    // macOS confirms a change asynchronously, so the status just read can be stale: look once more.
    if (PlatformInfo.isMacOS) {
      _delayedDefaultsRefresh?.cancel();
      _delayedDefaultsRefresh = Timer(macOsRefreshDelay, () => unawaited(refreshDefaults()));
    }
  }

  static const macOsRefreshDelay = Duration(milliseconds: 1500);

  Future<void> openSystemDefaultAppsSettings() async {
    final opened = await _defaultApp.openSystemDefaultAppsSettings();
    if (!opened) CustomSnackbar.error('Could not open Windows default-apps settings.');
  }

  /// "Ask me again": the first-run prompt may appear again.
  Future<void> askAboutDefaultAgain() async {
    await _defaultApp.resetPrompt();
    CustomSnackbar.success('OpenReader will offer to become your default reader again the next time it starts.');
  }

  // ---- Files & storage ----

  Future<void> setCacheCap(int? mb) async {
    cacheCapMb.value = mb;
    await _guard(() => _settings.setCacheCapMb(mb));
    await _applyCacheCap();
    await _loadStats();
  }

  Future<void> setHistoryRetention(int? days) async {
    if (days == 0 && historyRetentionDays.value != 0) {
      final turnOff = await showConfirmDialog(
        title: 'Turn off reading history?',
        message: 'OpenReader will stop recording what you open, and will no longer remember where '
            'you stopped reading, so Restore last position will not work.',
        confirmLabel: 'Turn off',
      );
      if (!turnOff) return;
      final clear = await showConfirmDialog(
        title: 'Also clear existing history?',
        message: 'Remove the entries already in your history and their saved reading positions. '
            'Your documents are not deleted. Cancel keeps them.',
        confirmLabel: 'Clear history',
        destructive: true,
      );
      if (clear) {
        final result = await _recents.clearAll();
        if (result.isRight()) _refreshHistoryViews();
      }
    }
    historyRetentionDays.value = days;
    await _guard(() => _settings.setHistoryRetentionDays(days));
    if (await enforceHistoryRetention(settings: _settings, recents: _recents)) _refreshHistoryViews();
  }

  /// Clear reading history (ST-07): asks first, then empties Recents/History and says so. The
  /// documents themselves are never touched.
  Future<void> clearHistory() async {
    final confirmed = await showConfirmDialog(
      title: 'Clear all reading history?',
      message: 'This will not delete your documents.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    final result = await _recents.clearAll();
    result.fold(
      (failure) => CustomSnackbar.error('Could not clear reading history: ${failure.message}'),
      (_) {
        _refreshHistoryViews();
        CustomSnackbar.success(historyClearedMessage);
      },
    );
  }

  static const historyClearedMessage = 'Reading history cleared. Your documents were not deleted.';

  void _refreshHistoryViews() {
    if (Get.isRegistered<RecentsController>()) unawaited(Get.find<RecentsController>().load());
    if (Get.isRegistered<HomeController>()) unawaited(Get.find<HomeController>().load());
  }

  Future<void> _applyCacheCap() async {
    final cap = cacheCapMb.value;
    if (cap == null) return;
    final result = await _pathService.getTempDirectory();
    await result.fold((_) async {}, (directory) async {
      await trimRenderCachesToCap(directory, cap * 1024 * 1024);
    });
  }

  Future<void> _loadStats() async {
    isLoadingStats.value = true;

    final tempDirResult = await _pathService.getTempDirectory();
    await tempDirResult.fold(
      (_) async {},
      (directory) async => cacheSizeBytes.value = await _cacheSize(directory),
    );
    isLoadingStats.value = false;
  }

  /// Bytes of render cache under the temp [directory], leaving out [protectedTempEntries].
  static Future<int> _cacheSize(Directory directory) async {
    var size = 0;
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(followLinks: false)) {
          if (protectedTempEntries.contains(p.basename(entity.path))) continue;
          try {
            if (entity is File) {
              size += await entity.length();
            } else if (entity is Directory) {
              await for (final inner in entity.list(recursive: true, followLinks: false)) {
                if (inner is File) size += await inner.length();
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }

  /// Clear render cache from Settings: asks first, then [clearCache].
  Future<void> confirmClearCache() async {
    final confirmed = await showConfirmDialog(
      title: 'Clear render cache?',
      message: 'Page images and thumbnails are deleted and rebuilt as you read. Your documents are not touched.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (confirmed) await clearCache();
  }

  /// The success message after clearing the cache, naming how much was freed.
  static String cacheClearedMessage(int freedBytes) => 'Render cache cleared. ${formatFileSize(freedBytes)} freed.';

  Future<void> clearCache() async {
    final result = await _pathService.getTempDirectory();
    await result.fold(
      (failure) async => CustomSnackbar.error(failure.message),
      (directory) async {
        try {
          final before = await _cacheSize(directory);
          if (await directory.exists()) {
            await for (final entity in directory.list()) {
              if (protectedTempEntries.contains(p.basename(entity.path))) continue;
              await entity.delete(recursive: true);
            }
          }
          final freed = before - await _cacheSize(directory);
          CustomSnackbar.success(cacheClearedMessage(freed < 0 ? 0 : freed));
          await _applyCacheCap();
          await _loadStats();
        } catch (e) {
          CustomSnackbar.error('Could not clear cache: $e');
        }
      },
    );
  }

  // ---- Help & about ----

  static const shareText =
      'OpenReader: read PDF, Word, Excel, PowerPoint, CSV, text and Markdown files.\n$playStoreUrl';

  /// Opens OpenReader's Play Store page (Android only; see [canRateApp]).
  Future<void> rateApp() async {
    var opened = false;
    try {
      opened = await _openUrl(playStoreUrl);
    } catch (_) {}
    if (!opened) CustomSnackbar.error('Could not open the Play Store.');
  }

  /// OpenReader's privacy policy (ST-06, Q2).
  static const privacyPolicyUrl = 'https://macdipu.github.io/OpenReader/privacy.html';

  /// Opens the privacy policy in the browser.
  Future<void> openPrivacyPolicy() async {
    var opened = false;
    try {
      opened = await _openUrl(privacyPolicyUrl);
    } catch (_) {}
    if (!opened) CustomSnackbar.error('Could not open the privacy policy.');
  }

  /// Where Send feedback goes: a new GitHub issue (needs a free GitHub account).
  static const feedbackIssueUrl = 'https://github.com/macdipu/OpenReader/issues/new';

  /// The new-issue link with a pre-filled, URL-encoded body: app version, OS name and version and
  /// platform, and an empty "What happened?" section. Never file names, paths or document content.
  static Uri feedbackUri({
    required String appVersion,
    required String osName,
    required String osVersion,
    required String platform,
  }) {
    final body = StringBuffer()
      ..writeln('## What happened?')
      ..writeln()
      ..writeln()
      ..writeln('## Environment')
      ..writeln('- App version: ${appVersion.isEmpty ? 'unknown' : appVersion}')
      ..writeln('- OS: $osName $osVersion')
      ..writeln('- Platform: $platform');
    return Uri.parse(feedbackIssueUrl).replace(queryParameters: {
      'title': 'Feedback: ',
      'body': body.toString(),
    });
  }

  /// Opens a pre-filled GitHub issue ([feedbackUri]).
  Future<void> sendFeedback() async {
    if (appVersion.value.isEmpty) await _loadAppVersion();
    var osName = defaultTargetPlatform.name;
    var osVersion = '';
    try {
      osName = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
    } catch (_) {}
    final uri = feedbackUri(
      appVersion: appVersion.value,
      osName: osName,
      osVersion: osVersion,
      platform: defaultTargetPlatform.name,
    );
    var opened = false;
    try {
      opened = await _openUrl(uri.toString());
    } catch (_) {}
    if (!opened) CustomSnackbar.error('Could not open the feedback page.');
  }

  Future<void> shareApp() async {
    try {
      await _share(shareText);
    } catch (_) {
      CustomSnackbar.error('Could not open the share sheet.');
    }
  }

  Future<void> showWelcomeAgain() async {
    final confirmed = await showConfirmDialog(
      title: 'Show welcome screens again?',
      message: 'The welcome screens appear the next time OpenReader starts.',
      confirmLabel: 'Show again',
    );
    if (!confirmed) return;
    await _guard(() => _settings.setOnboardingComplete(false));
    CustomSnackbar.success('The welcome screens will appear the next time OpenReader starts.');
  }

  static const resetMessage = 'All settings are back to their defaults. Your documents and history were not touched.';

  /// Puts every preference back to its default. The welcome and first-scan flags are kept, so this
  /// does not send the user back through onboarding or rescan their storage.
  Future<void> resetAllSettings() async {
    final confirmed = await showConfirmDialog(
      title: 'Reset all settings?',
      message: 'Appearance, reading, privacy and storage choices go back to their defaults. '
          'Your documents and history are not touched.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _settings.clearPreferencesKeepingSetup();
      await _guard(() => themeController.changeThemeMode(ThemeMode.system));
      await reload();
      // Open readers follow the defaults too.
      ReaderPreferences.publish(ReaderPreference.nightMode, nightMode.value);
      ReaderPreferences.publish(ReaderPreference.pdfContinuous, pdfContinuous.value);
      ReaderPreferences.publish(ReaderPreference.fontSize, fontSize.value);
      ReaderPreferences.publish(ReaderPreference.lineWrap, lineWrap.value);
      CustomSnackbar.success(resetMessage);
    } catch (e) {
      CustomSnackbar.error('Could not reset settings: $e');
    }
  }
}
