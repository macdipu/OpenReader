# TECH-SPEC: CR-SETTINGS-UX (Phases 1 and 2)

Frozen once the run's context is registered. Progress goes in `agentic/data/work-items/CR-SETTINGS-UX.md`, never here.
Scope: OpenReader only (no Kit change, no new dependency). Requirements ST-01..ST-15 from `CR.md`.
Decisions (user, 2026-11-21): technical approval by macdipu for Phases 1+2; safe defaults for open items.
- Telemetry switches default **ON** (today's behaviour), disclosed and switchable. The release default is on; debug stays off (`kDebugMode`).
- **Left out until the user supplies them:** Privacy Policy link (Q2), Send feedback (Q3). Phase 3 (ST-16..ST-20) is out. ST-15 stays in.
- Windows default-app status: spike `reg query`; if the output can't be parsed reliably, return `unknown` and the UI shows no status.
- macOS: ST-14 status via a new channel method only if the existing channel code allows it cleanly; otherwise `unknown` (button only) and record it.

## Work packages and file ownership (no two agents edit the same file)

### WP-A: data, telemetry, restore-position
Owns: `lib/core/domain/repositories/app_settings_repository.dart`, `lib/core/data/repositories/app_settings_repository_impl.dart`, `lib/app/flavours/app_flavour.dart`, new `lib/services/telemetry/telemetry_service.dart`, the five reader controllers' `getPosition` call sites (`sheet_reader_controller.dart`, `powerpoint_reader_controller.dart`, `text_reader_controller.dart`, `pdf_reader_controller.dart`, `word_reader_controller.dart`), their tests under `test/repositories`, `test/services`, `test/controllers`.

New `AppSettingsRepository` members (all with defaults when never set):
```dart
Future<bool> getRestoreReadingPosition();            // default true
Future<void> setRestoreReadingPosition(bool value);
Future<bool> getCrashReportsEnabled();               // default true
Future<void> setCrashReportsEnabled(bool value);
Future<bool> getAnalyticsEnabled();                  // default true
Future<void> setAnalyticsEnabled(bool value);
Future<int?> getCacheCapMb();                        // null = no cap
Future<void> setCacheCapMb(int? value);
Future<int?> getHistoryRetentionDays();              // null = forever, 0 = off (record nothing)
Future<void> setHistoryRetentionDays(int? value);
```
`clearSettings()` must also remove the new keys.

`TelemetryService` (singleton `TelemetryService.instance`): `Future<void> apply({required bool crashReports, required bool analytics})` calls `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(crashReports && !kDebugMode)` and `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(analytics && !kDebugMode)`, a no-op that returns normally on non-Android/iOS or when Firebase isn't initialised, and never throws. `Future<void> applySaved(AppSettingsRepository)` reads both flags and calls `apply`. `_initFirebase` in `app_flavour.dart` calls `applySaved` instead of the hard-coded enables, and still never blocks start.

Restore position: in each of the five `getPosition` call sites, read `getRestoreReadingPosition()` first; when false, skip applying the stored position (open at the start) but still save positions as the user reads. Saving is not changed.

History retention and cache cap are stored here (ST-11, ST-12) but enforced by WP-C's controller code (below).

### WP-B: platform services
Owns: `lib/services/utilities/storage_access_service.dart`, `lib/services/platform_integration/default_app_service.dart`, `macos/Runner/*` (only if ST-14 goes ahead), tests under `test/services`.

`StorageAccessService` adds:
```dart
enum StorageAccessState { allowed, notAllowed, blocked, notApplicable }
Future<StorageAccessState> state();   // iOS/desktop => notApplicable
```
built from `hasAccess()` and `isPermanentlyDenied()`. Existing methods stay unchanged.

`DefaultAppService` adds:
```dart
enum DefaultStatus { isDefault, otherApp, unknown }
Future<Map<DocumentType, DefaultStatus>> queryDefaults();   // never throws; unsupported platform => all unknown
@visibleForTesting static DefaultStatus parseXdgDefault(String stdout);      // 'openreader.desktop' => isDefault
@visibleForTesting static DefaultStatus parseWindowsProgId(String stdout, {required String appProgId});
Future<bool> openSystemDefaultAppsSettings();                // Windows: ms-settings:defaultapps; others false
```
Linux uses `xdg-mime query default <mime>`; Windows uses `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.<ext>\UserChoice" /v ProgId`. Parsing functions are pure and tested with fixture strings. `Process.run` goes through an injectable runner so tests don't spawn processes. Reset of the first-run prompt: `Future<void> resetPrompt()` clears the dismissed and shown keys (ST-15).

### WP-C: settings UI (starts after WP-A and WP-B are merged)
Owns: everything under `lib/features/settings/presentation/` plus `lib/core/presentation/widgets/app_shortcuts.dart`, `lib/app/shell/app_shell.dart`, `lib/app/shell/desktop_sidebar.dart`, tests under `test/widgets` (new file `settings_view_test.dart`).
Builds ST-01..ST-10, ST-11 and ST-12 enforcement, ST-13, ST-14 UI, ST-15 UI, using WP-A and WP-B APIs exactly as written above.
- Section widgets split out of `settings_view.dart` into `lib/features/settings/presentation/sections/`; shared row/card widgets keep the current look.
- `SettingsController` gains the observable state for each preference and calls the repository; theme, night mode, PDF mode, font size and line wrap keep one source of truth (the repository plus the existing controllers) so reader toolbars and Settings agree.
- Clear history reuses `confirmClearHistory` from `favorites_view.dart`.
- Cache cap: after each settings-page load and after clear, trim `PathService` temp files oldest-first down to the cap. History retention: on Settings load and on app start, delete history older than the chosen days through the existing `RecentRepository` (add a method only if none fits; touching `recent_repository*.dart` is allowed for that one method).
- Desktop (≥900px): two-pane with the section list; arrow keys and Tab; Ctrl/Cmd+, opens Settings from the shell (`settingsIndex`).
- Section visibility per platform exactly as the table in `CR.md`; telemetry switches and the privacy statement name Google Firebase; no Privacy Policy link, no Send feedback row.

### WP-D: independent review and QA (starts after WP-C)
Read-only review of the full diff against `CR.md` acceptance criteria, then `flutter test` and `flutter analyze`.

## Verification
- `flutter test` all green, `flutter analyze` 0 errors and 0 warnings (infos may stay at the baseline of 80).
- New tests: repository defaults and clear; telemetry apply (mocked); restore flag at each reader controller; parse functions; `StorageAccessService.state()`; settings widget tests at 360, 700 and 1200 px for Android, iOS, macOS, Windows, Linux section visibility; settings and toolbar sync; Ctrl/Cmd+, shortcut.
- Manual checks on real devices are left to the user and recorded as gaps.

## Constraints
- No new dependencies. Do not run `dart format` on whole files. Do not edit `CLAUDE.md`, `pubspec.yaml`, `pubspec.lock`, or the Kit. Do not commit.
- Never invent status: unreadable permission or default status shows nothing.
