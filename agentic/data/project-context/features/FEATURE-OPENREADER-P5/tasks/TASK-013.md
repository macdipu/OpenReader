# Engineering Task

## Status
DONE (implemented, `flutter analyze`/`flutter test` verified) — 2026-09-19. Implemented against `SRS.md`/`ARCHITECTURE.md`'s first implementation slice, item (a)'s second half (ODF-P5-01 `.env` fix was already done in a prior session step, commit `2aeae27`). No ADR needed — no new dependency, matching this phase's posture.

## Story
CI config (BRD Phase 5, hardening — Dependency audit / Security)

## Objective
ODF-P5-07: add a CI config (`.github` was absent) so `flutter analyze`/`flutter test` run automatically on push/PR instead of only ever being run manually in-session.

## Dependencies
- No new library or app dependency. Uses `subosito/flutter-action@v2`, a GitHub Actions marketplace action, pinned to this project's `.fvmrc` Flutter version (`3.44.4`) so CI matches the SDK constraint the rest of the project is verified against.
- No code-path change — this is build-tooling only, per `SRS.md` Interfaces section.

## Implementation Requirements (as built)
- `.github/workflows/ci.yml`: single job (`analyze-and-test`) on `ubuntu-latest`, triggered on push/PR to `main`. Steps: checkout, install Flutter 3.44.4 (stable channel, with action-level caching), `flutter pub get`, `flutter analyze`, `flutter test`.
- No matrix, no multi-OS build, no release/artifact steps — scope is strictly "run the two checks that were previously only run manually," matching `SRS.md` ODF-P5-07's stated requirement, not a full release pipeline.

## Acceptance Criteria
- ODF-P5-07: met — `.github/workflows/ci.yml` exists and runs `flutter analyze` + `flutter test` on every push/PR to `main`.

## Validation
Verified locally in this session (dev host, Flutter 3.47.2 — newer than the pinned 3.44.4, but the same commands CI runs):
- `flutter pub get`: succeeds.
- `flutter analyze`: 0 errors, 0 warnings, 152 pre-existing infos (consistent with the baseline every prior phase recorded).
- `flutter test`: 122/124 passing. The 2 failures (`test/services/file_scanner_service_test.dart`: "discovers supported extensions..." and "includes depth eight but not depth nine") are a pre-existing bug unrelated to this task or to any change in this session — `FileScannerService._nameOf()` (`lib/services/utilities/file_scanner_service.dart:95-98`, renamed from `DocumentScannerService` — see TASK-014) splits on `/` only, so on this Windows dev host (backslash paths) it returns the full path instead of the basename. This is invisible on the CI runner itself (`ubuntu-latest`, forward-slash paths) and in real Android use (always forward-slash), so it does not affect CI's actual pass/fail signal on this codebase — but it is a genuine latent bug if this project is ever tested on Windows or the scanner's root-candidate paths change. Not fixed here: out of ODF-P5-07's scope (CI config, not test correctness), not part of the confirmed first-slice item list, and would need its own scoped fix (e.g. `package:path`'s `basename()`) rather than a one-line patch under this task.

## References
- `SRS.md` ODF-P5-07, Unresolved Specification Question 1 (confirmed implementation order: `.env`/CI first)
- `ARCHITECTURE.md` (Design boundaries: no new dependency, no ADR for this phase)
- `.fvmrc` (Flutter version pin this workflow matches)

## Out of Scope
- The Windows-path `_nameOf()` bug surfaced during validation (see above) — not fixed, documented as a new latent-bug finding for a future task.
- ODF-P5-03/04/05/06/08 — later items in the same confirmed implementation order, not started by this task.

## Additional finding, now fixed: cold-start splash hang on real emulator

After CI/`.env` work, the user asked to run the app on an actual Android emulator — the first time in this project's history the app has been launched on any device/emulator (every prior phase's "known_risks" noted no Android SDK/emulator had ever been available). Ran on `emulator-5554` (Android 17/API 37, x86_64 system image), Flutter 3.47.2.

**Symptom: the app never got past the splash screen**, across every clean install-and-launch attempt (confirmed via screenshot each time, several minutes of wait each).

**Investigation initially went down a wrong path.** `SplashController._bootstrapAndRoute()` calls `AppSettingsRepositoryImpl.hasCompletedOnboarding()`, which read through `SharedPreference` (`lib/core/data/cache/preference/shared_preference.dart`) — despite its name, that class wraps `FlutterSecureStorage`, not `shared_preferences`. Its first-ever read triggered a one-time Android-Keystore cipher migration (logged "Step 1/6" through "Data migration completed successfully!"), and the app still never proceeded, which looked like a plugin/engine-level hang. A 5-second `Future.timeout()` was added as a defensive measure and `AppSettingsRepositoryImpl` was switched from `FlutterSecureStorage` to plain `shared_preferences` (legitimate improvement, kept — see `lib/core/data/repositories/app_settings_repository_impl.dart`: none of theme/locale/onboarding-flag are sensitive, and `shared_preferences` was already a dependency). **Neither fixed the hang.**

**Real root cause, found via elimination:** a purely synchronous `Get.offAllNamed()` call placed directly in `SplashController.onInit()` — zero awaits, zero plugin calls — still failed to navigate, and a `debugPrint` placed at the very first line of `onInit()` never printed at all (while `debugPrint` calls elsewhere in the same run, e.g. the navigation observer's own logging, printed fine). This proved `SplashController.onInit()` was never being called, i.e. **`SplashController` was never being instantiated.**

`SplashView` (`lib/features/splash/presentation/splash_view.dart`) is a `GetView<SplashController>`, but its `build()` never references `controller` anywhere (it's a static loading screen — icon, text, spinner, no dynamic content). `SplashBinding` (`lib/features/splash/presentation/splash_binding.dart`) registered the controller with `Get.lazyPut`, which only constructs the instance the first time something calls `Get.find<SplashController>()` / touches `GetView.controller`. Since `SplashView` never does that, `SplashController` — and the `onInit()` bootstrap-and-navigate-away logic it drives — was **never created at all**. The app was permanently stuck showing the static view, with nothing ever running to move it forward. This had nothing to do with `FlutterSecureStorage`, `sqflite`, `shared_preferences`, or GetX's navigation internals — those were all red herrings chased before the real cause was isolated.

**Fix:** `SplashBinding.dependencies()` now uses `Get.put(SplashController())` (eager) instead of `Get.lazyPut` — matching how `ThemeController`/`LocaleController` are already registered eagerly in `lib/app/views/app.dart`. Eager `Get.put` runs the constructor (and `onInit()`) immediately when the binding executes at route entry, independent of whether the view ever reads `.controller`.

**Verified fixed end-to-end on the emulator**: fresh install → splash → `NAV:PUSH new=/onboarding | old=/splash` observed in logcat → tapped "Not Now" → app shell loads (Home/Files/Favorites/Settings tabs, "Grant Access" limited-mode prompt shown correctly per BRD 9.2 Scenario B). `flutter analyze` (0 errors/warnings, 152 pre-existing infos) and `flutter test` (122/124, same 2 pre-existing unrelated failures) both still pass after the fix.

This resolves the total-blocker status: manual QA of every phase's reader is now actually possible on this emulator for the first time. ODF-030 (large-file responsiveness) itself remains unverified — no large-file corpus exists yet — but the standing blocker ("the app doesn't boot at all") is gone.
