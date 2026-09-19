# Engineering Task

## Status
DONE — 2026-09-19. Implements `SRS.md`/`ARCHITECTURE.md`'s first implementation slice, item (d): ODF-P5-06 dependency reconciliation. Each flagged item was individually reconciled (fixed, reaffirmed, or removed) rather than treated as one block; a fifth item (`VersionUpdateService`, surfaced by `TASK-016.md`'s offline audit) was added to scope with the user's explicit approval before any removal.

## Story
Dependency reconciliation (BRD Phase 5, hardening — Dependency audit)

## Objective
Reconcile the dependency-audit items flagged across P1-P4 but never revisited together: `pdfrx` version pin, the local `file_picker` patch, the `receive_sharing_intent` Kotlin-version mismatch, `docx_file_viewer`'s bus-factor risk - plus `VersionUpdateService`'s dead-code finding from `TASK-016.md`.

## Reconciliation, item by item

**`pdfrx` version pin (2.4.8, not latest).** Reaffirmed, not changed. `ADR-OPENREADER-pdf-library.md` already made this an explicit, revisitable decision (Alternative 2: bump the Flutter SDK floor to adopt `pdfrx` 2.5.0+ later). That bump is a project-wide decision - it would touch `.fvmrc`, CI's pinned Flutter version, and require re-verifying ~60 other dependencies against the new SDK floor - out of proportion to a reconciliation pass and explicitly deferred by the ADR itself, not this task's call to make. No action taken; still correctly pinned.

**`file_picker` local patch (`packages/file_picker`, path override in `pubspec.yaml`).** Reaffirmed, not changed. The patch stubs the Windows platform implementation solely so `flutter analyze`/`flutter test`/`flutter pub get` resolve on this Windows dev host alongside other plugins' `win32` constraints - a dev-tooling necessity, not a shipped-product concern (OpenReader targets Android/Play Store per `ADR-OPENREADER-storage-access.md`; Windows was never a target platform). No upstream fix would remove the need for this, since the conflict is between this project's own plugin set's `win32` version requirements, not a bug in `file_picker` itself.

**`receive_sharing_intent` Kotlin-version mismatch.** Corrected the record and fixed the real issue underneath it. Ran a real `flutter build apk --debug` against this project's now-available Android toolchain (Android SDK 36.1.0, emulator - unavailable in every prior phase, first used in `TASK-013.md`) rather than continuing to treat this as unverifiable. Findings:
- The "Kotlin 2.4.0 required vs. 2.2.20 pinned" framing was **not actually a build blocker** - Gradle only emits a soft "Flutter support for your Kotlin version will soon be dropped" deprecation notice (Flutter's own minimum-support-window policy, unrelated to `receive_sharing_intent` specifically), and the build succeeds regardless.
- The build log surfaced the **real, concrete issue**: `receive_sharing_intent` requires `compileSdk 37`, but `android/app/build.gradle.kts` resolved `compileSdk = flutter.compileSdkVersion`, which is `36` on this Flutter version - a genuine (if minor) mismatch, with Flutter's own build output naming the exact fix.
- **Fixed**: hardcoded `compileSdk = 37` in `android/app/build.gradle.kts` (backward-compatible; doesn't affect `minSdk`/`targetSdk`). Re-ran `flutter build apk --debug` - the `receive_sharing_intent` compileSdk warning is gone, build still succeeds (38-56s, `app-debug.apk` produced both times).
- The remaining Gradle 8.14.0/AGP 8.11.1/Kotlin 2.2.20 deprecation warnings are project-wide toolchain-upgrade notices unrelated to `receive_sharing_intent`, same category of "larger, separate decision" as the `pdfrx` SDK bump - not addressed here.

**`docx_file_viewer` bus-factor/low-adoption risk.** Reaffirmed, not changed. No alternative exists (`ADR-OPENREADER-office-libraries.md` already surveyed the DOCX-rendering library landscape for P3; nothing has changed since). Documented risk, no available mitigation beyond what P3 already recorded.

**`VersionUpdateService`/`app_version_update` (new finding, `TASK-016.md`).** User explicitly chose removal over documenting-only when asked, given: not referenced by any BRD requirement (a full-text grep of `OpenReader_BRD_v1.0.md` finds zero mentions of update-checks, push notifications, or Firebase), and the entire notification/Firebase bootstrap was already dormant (commented out with a "TODO: Enable Firebase for production" marker, per `TASK-016.md`). Removed as one unit, since all three were the same inherited, unwired scaffolding:
- Deleted `lib/services/push_notification/` (`notification_service.dart`, `firebase_notification_service.dart`, `local_notification_service.dart`) and `lib/services/utilities/version_update_service.dart`.
- `lib/app/flavours/app_flavour.dart`: removed the `NotificationService` import, its `Get.lazyPut` registration, and the already-commented-out `Firebase.initializeApp()`/`NotificationService().init()` lines (nothing to migrate - they were never live).
- `pubspec.yaml`: removed `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `app_version_update` (13 transitive packages dropped per `flutter pub get`'s own count). `home_widget`/`workmanager`/`timezone`/`flutter_timezone` (same "Weather Pulse" template-comment block, also unreferenced anywhere in `lib/`) were **not** touched - out of the scope the user approved, which named Firebase/notifications/version-update specifically; flagged below for a future pass rather than removed unilaterally.
- No Android/iOS platform config existed to clean up: no `google-services.json`/`GoogleService-Info.plist`, no `com.google.gms.google-services` Gradle plugin, no Firebase/notification entries in `AndroidManifest.xml` - confirming this was Dart-level-only scaffolding that was never actually platform-wired, not a partially-shipped feature.

## Acceptance Criteria
- ODF-P5-06: met — every flagged item individually reconciled (pin reaffirmed, patch reaffirmed, Kotlin/compileSdk mismatch fixed, bus-factor risk reaffirmed with no available mitigation, dead code removed per explicit user decision).

## Validation
- `flutter pub get`: succeeds, 13 dependencies removed cleanly, no conflicts.
- `flutter analyze`: 0 errors, 0 warnings, 133 infos (down from the established 152-info baseline - expected, since the removed files carried some of those infos; no new issues introduced).
- `flutter test`: 134/136 passing - same 2 pre-existing, unrelated Windows-path-separator failures as every prior phase's baseline (`TASK-013.md`), no regressions from the removal.
- `flutter build apk --debug`: succeeds both before and after the `compileSdk` fix (confirms the fix resolves the specific warning without breaking the build), and again after the dead-code removal (confirms nothing else depended on the removed modules at the Android build level).

## References
- `SRS.md` ODF-P5-06, Unresolved Specification Question 1 (confirmed implementation order: item (d), last of the "actionable now" bucket before ODF-P5-08)
- `ADR-OPENREADER-pdf-library.md` (pdfrx pin decision and its own explicitly-deferred Alternative 2)
- `ADR-OPENREADER-office-libraries.md` (docx_file_viewer's original library survey)
- `TASK-016.md` (VersionUpdateService dead-code finding this task acts on)
- `TASK-013.md` (first working Android emulator/toolchain in this project's history, made the real `flutter build apk` verification here possible)

## Out of Scope
- Bumping the Flutter SDK floor (would unblock `pdfrx` 2.5.0+ and the Gradle/AGP/Kotlin upgrade warnings) - a project-wide decision, not this reconciliation pass's call.
- `home_widget`/`workmanager`/`timezone`/`flutter_timezone` - equally unreferenced in `lib/`, but outside the scope the user approved for removal in this task; flagged here for a future dependency-audit pass rather than removed unilaterally.
- ODF-P5-08 — the next and final item in the confirmed implementation order, not started by this task.
