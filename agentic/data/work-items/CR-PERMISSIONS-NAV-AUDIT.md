# CR-PERMISSIONS-NAV-AUDIT: least-privilege permissions and simpler navigation

## Request (user, 2026-11-21)
"Audit and optimize permission handling and screen navigation. Follow the principle of least privilege: request only essential permissions, only when needed, and explain their purpose. Prefer scoped access and system pickers. Ensure graceful handling of denied permissions and full compliance with Android/iOS policies, privacy, and security standards. Also review and simplify navigation routes, screen transitions, and navigation hierarchy. Remove unnecessary complexity while preserving existing functionality and UI/UX. Audit first, then make only necessary improvements."

Earlier in the same session the user also asked: do the permission work wisely, request no unnecessary permission, keep all policy and standards. A further phrase, "chaniz rooms", could not be parsed and is open.

## Plan
1. INTAKE (this document).
2. CONTEXT: read-only audit in three parts (Android permissions, Apple/desktop permissions and privacy compliance, navigation) into `agentic/data/project-context/features/CR-PERMISSIONS-NAV-AUDIT/AUDIT-REPORT.md`.
3. Necessary improvements only, each traced to an audit finding; tests; QA on the Android 11 phone.

## Known starting facts
- Observed on an Android 11 phone (2026-11-21): the not-allowed action showed the legacy "photos and media" dialog, which grants nothing useful on Android 11+; the status was stale after returning from the OS page; the "limited mode" note showed while access was granted. Fixes for these are in progress under CR-SETTINGS-UX.
- Release manifest permissions beyond the app's own come from unused plugins `workmanager` (POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE) and `home_widget`.

## Run
`RUN-D8B11A2F3B8541A99E60C6F3BDD559B5` (change_request, NO_REPLAN). Technical gate approved by macdipu 2026-11-21 (scope: all necessary items; keep All files access; backup off; Back to Home first; predictive back flag).

## Status
QA recorded 2026-11-21 (stage QA, run RUNNING; RELEASE gate needs the user's approval). Implemented and committed on `main` (not pushed). `flutter test` 607 pass; `flutter analyze` 0 errors, 0 warnings. Independent review found 2 blockers (updater redirect host, Windows zip copy) and 6 should-fix items; all fixed except S5 (Android 10, unverified) and S4 (accepted trade-off). Verified on a real OPPO Android 11 (ColorOS) and a Redmi Android 13 (Xiaomi ROM): cold start of the release build, permissions, status refresh, guidance snackbar (hardware Back and toolbar arrow), Back on Browse.
User changes during the run: "Not Now" removed from Android onboarding; snackbar redesigned (message full width, button below) and its button opens the All files access page.

Open: other phones (Samsung SM-A546E, OPPO CPH2565), Android 10, desktop updater end to end and release.yml in CI, Play Console declarations, iOS pre-submission items (B-03, B-05, B-06, B-07, B-12), optional audit items. Evidence: `agentic/data/project-context/features/CR-PERMISSIONS-NAV-AUDIT/validation/`.
