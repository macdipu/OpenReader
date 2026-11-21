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

## Status
INTAKE. Audit running.
