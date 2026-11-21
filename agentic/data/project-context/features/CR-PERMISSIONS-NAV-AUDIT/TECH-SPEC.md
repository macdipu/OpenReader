# TECH-SPEC: CR-PERMISSIONS-NAV-AUDIT

Frozen once the run's context is registered; progress goes in `agentic/data/work-items/CR-PERMISSIONS-NAV-AUDIT.md`. Source: `AUDIT-REPORT.md` (same folder). Finding ids below refer to it.

## Decisions (user, 2026-11-21)
- Make all items classed "Necessary" in the audit; each gets a test; Android checked on the user's phones.
- A-01: keep MANAGE_EXTERNAL_STORAGE. The Play Console declaration is the owner's task. No SAF work in this CR.
- A-05: app backup off (`android:allowBackup="false"`; also `dataExtractionRules` excluding everything so Android 12+ lint is satisfied).
- N-02: on narrow layouts, Back on the Browse or Favorites tab goes to Home first; Back on Home exits.
- N-03: add `android:enableOnBackInvokedCallback="true"`.
- Chinese-ROM compatibility is in scope through A-12..A-15.
- Optional items (A-08, A-09, A-16, B-09, B-13, B-15, B-16, N-04..N-08) are out of this CR. B-03, B-05, B-06, B-07, B-12 (iOS pre-submission) are out until iOS ships; B-04 (iOS app name) is in.

## Work packages and file ownership

### WP-1 Desktop updater security (B-01, B-02, B-08, B-10, B-11)
Owns: `lib/services/utilities/desktop_update_installer.dart`, `lib/services/utilities/app_update_service.dart`, `.github/workflows/release.yml`, tests under `test/services`.
- Download URL must be `https` with host `github.com` or `objects.githubusercontent.com` (also after redirects); otherwise fall back to opening the release page in the browser, as when the install folder is not writable.
- `release.yml` publishes `SHA256SUMS` next to the desktop assets (one line per asset, `sha256sum` format). The updater fetches `SHA256SUMS` from the same release (same host rules), computes the SHA-256 of the downloaded file and refuses to stage or run it on a mismatch or when no entry exists; the user sees a clear message and the browser fallback is offered.
- macOS: remove `xattr -dr com.apple.quarantine`.
- Linux: stage the update in a per-user directory with mode 0700 (`getApplicationSupportDirectory()`/`XDG_CACHE_HOME`, or `Directory.systemTemp.createTemp`), never a fixed path in shared `/tmp`.
- Update scripts (shell and PowerShell) take paths as arguments or single-quoted strings, never interpolated into script text.
- Tests: URL/host validation; checksum parse and verify (match, mismatch, missing entry); script generation has no interpolated paths; Linux staging dir is per-user.

### WP-2 Android manifest, dependencies, native (A-02, A-04, A-07, A-05, N-03)
Owns: `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`, `android/app/src/main/res/xml/data_extraction_rules.xml` (new), `android/app/src/main/kotlin/**/MainActivity.kt` (after the settings agent is done with it), `pubspec.yaml`/`pubspec.lock` (dependency removal only), tests.
- Remove `workmanager` and `home_widget` from `pubspec.yaml`, with `androidx.work` lines (`build.gradle.kts:86-91` and their comment) and the two WorkManager/Room keep rules (`proguard-rules.pro:1-4`) together; keep `coreLibraryDesugaring` unless a remaining dependency is verified not to need it. Run `flutter pub get`. Verify with `flutter build apk --release` and a cold start on a phone; confirm the merged release manifest has no POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, `androidx.work` or Glance services.
- `READ_EXTERNAL_STORAGE`: `maxSdkVersion="29"`.
- `android:enableOnBackInvokedCallback="true"` on `<application>`; `android:allowBackup="false"`, `android:dataExtractionRules="@xml/data_extraction_rules"` (exclude all domains).
- `MainActivity.kt` incoming copy: name keyed by a hash of the URI (or size + modified time) so two different files with the same name do not collide; keep the sanitising and the age prune.

### WP-3 Permission flow robustness (A-03, A-06, A-12, A-13, A-14, A-15)
Owns: `lib/services/utilities/storage_access_service.dart`, `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/app/shell/app_shell_controller.dart`, `lib/features/home/presentation/home_view.dart`, `lib/features/browse/presentation/browse_controller.dart`, `lib/features/onboarding/**`, `lib/features/settings/presentation/sections/permissions_section.dart` (wording only), tests. Starts after the settings redesign agent has finished.
- A-03: the "still accessible" check runs only for paths on shared storage; paths inside the app's cache or files directories skip the permission check.
- A-12: one shared "re-check after returning" helper (checks at once, ~0.7 s, ~1.5 s, ~3 s; stops when the state changes or the owner is disposed) used by the shell resume check, Home, Browse, the Grant-Access snackbars and onboarding.
- A-13: when the user returns from the OS page without access, show the how-to guidance with "Open app settings" (not on stock flows that succeed).
- A-14/A-15: help and denied texts say to choose "Allow management of all files" rather than "media only", with short per-vendor lines (ColorOS/realme, Xiaomi/HyperOS, vivo, Samsung).
- A-06: onboarding text and the Home banner state the purpose, that files are never uploaded or shared, and link to the privacy policy (`https://macdipu.github.io/OpenReader/privacy.html`).

### WP-4 Navigation (N-01, N-02)
Owns: `lib/app/shell/app_shell.dart`, `lib/core/presentation/controllers/document_interaction_controller.dart` (shared with WP-3: run after it), tests.
- N-01: reproduce first with a test (second same-type reader push while one is open). If confirmed, replace the top reader instead of ignoring the push.
- N-02: narrow layouts: Back on tab index 1 (Browse) or 2 (Favorites) goes to Home (index 0); Back on Home exits; Browse folder-up keeps priority; fullscreen reader keeps priority. Test with the nested PopScopes.

### WP-5 iOS name (B-04)
Owns: `ios/Runner/Info.plist` display name and bundle name only ("OpenReader"). The working tree may hold unrelated uncommitted `ios/` changes: do not revert them and do not commit them.

## Verification
- `flutter analyze` 0 errors/0 warnings; full `flutter test` green.
- Release build on the OPPO Android 11 phone: cold start, first-launch flow, Settings > Permissions, grant/deny/revoke, reopen a shared file in limited mode, back gesture in Browse and in a fullscreen reader; merged release manifest check as above. Other Android versions on the user's other phones, one at a time.
- Manual gaps recorded: macOS and Windows updater end to end, Linux updater, real vendor ROMs other than ColorOS.

## Constraints
- No new dependencies. Keep the Kit untouched. Do not edit CLAUDE.md or AGENTS.md. No whole-file `dart format`. No commits by agents.
