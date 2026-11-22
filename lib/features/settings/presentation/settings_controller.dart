import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/models/keep_state.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/dynamic_color_preferences.dart';
import '../../../core/presentation/controllers/reader_preferences.dart';
import '../../../core/presentation/controllers/reader_wakelock.dart';
import '../../../core/presentation/controllers/theme_controller.dart';
import '../../../core/presentation/controllers/thumbnail_preferences.dart';
import '../../../core/presentation/utils/platform_info.dart';
import '../../../core/presentation/utils/storage_access_help.dart';
import '../../../core/presentation/widgets/show_dialog/confirm_dialog.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/platform_integration/default_app_service.dart';
import '../../../services/utilities/shared_copy_store.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../../../services/utilities/access_recheck.dart';
import '../../../services/utilities/url_launcher_service.dart';
import '../../home/presentation/home_controller.dart';
import '../../recents/presentation/recents_controller.dart';
import '../../text_reader/presentation/text_reader_controller.dart';

/// Settings screen (BRD 9.18, DESIGN_SPEC.md #01).
///
/// Every preference lives in [AppSettingsRepository] (the readers read it when they open and write
/// it from their toolbars); this controller mirrors it for the screen and [reload]s whenever
/// Settings comes into view, so both sides show the same value. Theme stays with [ThemeController].
class SettingsController extends GetxController with WidgetsBindingObserver {
  final AppSettingsRepository _settings;
  final RecentRepository _recents;
  final StorageAccessService _storageAccess;
  final DefaultAppService _defaultApp;
  final Future<void> Function(String text) _share;
  final ThemeController? _theme;
  final Future<bool> Function(String url) _openUrl;

  SettingsController({
    AppSettingsRepository? settings,
    RecentRepository? recents,
    StorageAccessService? storageAccess,
    DefaultAppService? defaultApp,
    Future<void> Function(String text)? share,
    ThemeController? themeController,
    Future<bool> Function(String url)? openUrl,
  })  : _settings = settings ?? AppSettingsRepositoryImpl(),
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

  final appVersion = ''.obs;

  // Reading
  final pdfContinuous = true.obs;
  final nightMode = false.obs;
  final fontSize = TextReaderController.defaultFontSize.obs;
  final lineWrap = true.obs;
  final restorePosition = true.obs;
  final hideThumbnails = false.obs;
  final keepScreenAwake = false.obs;

  // Privacy & data (Android): copies of files other apps shared (CR-FILE-RELOCATE)
  final sharedCopyAction = SharedCopyAction.ask.obs;
  final sharedCopyBytes = 0.obs;

  /// Only Android copies a file another app shares into the app.
  static bool get hasSharedCopies => PlatformInfo.isAndroid;

  // Appearance
  final useDynamicColor = false.obs;

  /// Whether the system offers a dynamic palette (ST-20); the switch is hidden when it doesn't.
  bool get dynamicColorAvailable => DynamicColorPreferences.available;

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

  /// After the OS permission page, the state can lag behind the user's choice: re-check a few times
  /// after returning, until it differs from what it was before leaving.
  final _permissionRecheck = AccessRecheck();

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
    _permissionRecheck.cancel();
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

  /// Re-reads every preference and the platform status. Called when Settings is shown.
  Future<void> reload() async {
    await _loadPreferences();
    unawaited(refreshPermissions());
    unawaited(refreshDefaults());
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
    await read(() async => sharedCopyAction.value = await _settings.getSharedCopyAction());
    await read(() async => sharedCopyBytes.value = await SharedCopyStore().usedBytes());
    await read(() async {
      useDynamicColor.value = await _settings.getUseDynamicColor();
      DynamicColorPreferences.enabled.value = useDynamicColor.value;
    });
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

  /// Refreshes now, then again after each of [AccessRecheck.defaultDelays], stopping as soon as the state
  /// differs from [before] (the state shown before the user left for the OS page) or the controller
  /// closes. A grant can reach the app a moment after it returns to the foreground.
  Future<void> watchPermissions(StorageAccessState? before) => _permissionRecheck.run(
        check: refreshPermissions,
        changed: () => storageState.value != before,
        isClosed: () => isClosed,
      );

  /// The action that matches the state: open the All files access page (Android 11+) or ask (older
  /// Android) when not allowed, explain and open the page when blocked, open the All files access page to
  /// manage it when allowed.
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
        // Revoking is done on the All files access page (Android 11+); the service opens the app's
        // settings instead on Android 10 and older, where Permissions > Storage is.
        await _storageAccess.openAllFilesAccessSettings();
      case StorageAccessState.notApplicable:
      case null:
        break;
    }
    await watchPermissions(before);
  }

  /// The by-hand steps for this phone's brand and Android version.
  Future<StorageAccessHelp> accessHelp() => loadStorageAccessHelp(_storageAccess);

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

  // ---- Data ----

  /// Labels for [SharedCopyAction], as shown in the row and the picker.
  static String sharedCopyActionLabel(SharedCopyAction action) => switch (action) {
        SharedCopyAction.ask => 'Ask me',
        SharedCopyAction.keep => 'Keep it',
        SharedCopyAction.remove => 'Remove it',
      };

  /// "When closing a file from another app": a picker for ask, keep or remove.
  Future<void> chooseSharedCopyAction() async {
    final chosen = await Get.dialog<SharedCopyAction>(
      SimpleDialog(
        title: const Text('When closing a file from another app'),
        children: [
          for (final action in SharedCopyAction.values)
            SimpleDialogOption(
              onPressed: () => Get.back(result: action),
              child: Row(
                children: [
                  Icon(action == sharedCopyAction.value ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  const SizedBox(width: 12),
                  Text(sharedCopyActionLabel(action)),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    sharedCopyAction.value = chosen;
    await _guard(() => _settings.setSharedCopyAction(chosen));
  }

  /// Removes the copies of other apps files that are not kept or a favorite (and their Recents
  /// entries). Asks first.
  Future<void> clearSharedCopies() async {
    final confirmed = await showConfirmDialog(
      title: 'Clear files from other apps?',
      message: 'Copies OpenReader holds of files other apps shared will be removed, with their Recents. '
          'Files you kept or marked as favorites stay. The original files are not touched.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    await SharedCopyStore().clear();
    sharedCopyBytes.value = await SharedCopyStore().usedBytes();
    _refreshHistoryViews();
    CustomSnackbar.success('Cleared files from other apps.');
  }

  /// "12.4 MB", for the storage row.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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

  static const resetMessage = 'All settings are back to their defaults. Your documents and history were not touched.';

  /// Puts every preference back to its default. The welcome and first-scan flags are kept, so this
  /// does not send the user back through onboarding or rescan their storage.
  Future<void> resetAllSettings() async {
    final confirmed = await showConfirmDialog(
      title: 'Reset all settings?',
      message: 'Your reading, appearance and privacy choices go back to their defaults. '
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
