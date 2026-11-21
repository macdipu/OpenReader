# CR-SETTINGS-UX: a useful Settings page on mobile and desktop

## Run
`RUN-9F80608414584F88B084BE68499D3FB3` (change_request, NO_REPLAN), registered 2026-11-21. Technical gate approved by macdipu (Phases 1+2, safe defaults). CR-OWN-ENGINES (`RUN-60D2C2882A324C15AAD0FBB0A9DC42DF`) is still open at REVIEW and untouched.

## Request (user, 2026-11-21)
1. "In mobile apps, the settings page is not that useful; plan how it can be more useful."
2. "Plan for both mobile and desktop."
3. "Add permission settings navigation; also do a detailed R&D of what can be added."
4. "For Windows and Linux, make it the default-app option" (instead of hiding the permission slot).
5. "Show me the final planning", then "Write the CR."

## Documents
- CR: `agentic/data/project-context/features/CR-SETTINGS-UX/CR.md`: requirements ST-01 to ST-20, acceptance criteria AC-01 to AC-11, open questions Q1 to Q8.
- Traceability: BRD §9.2, §9.18; DESIGN_SPEC #01.

## Status
QA refreshed 2026-11-21 on the final tree: `flutter test` 458 pass; `flutter analyze` 0 errors, 0 warnings, 97 infos. Committed on branch `cr-settings-ux` (not pushed). `docs/privacy.html` corrected draft is left uncommitted on purpose: it has owner placeholders and GitHub Pages would publish it. RELEASE gate needs the user's approval.

Standard-UX pass (2026-11-21, user chose standard platform UX): cache size limit is a picker row (bottom sheet on Android/iOS, dialog on desktop); file-access and default-app statuses carry an icon plus text; sentence-case section headers (heading semantics); clear history, clear render cache and reset all confirm with the error colour and then show a success snackbar (clear cache gained its confirm); chevrons only on rows that navigate or open something; leading icons on Theme, PDF default view, Text size and Keep reading history; desktop section list has an indicator bar, bold text, `selected` semantics and a keyboard-only focus ring; switch rows are one keyboard stop. Send feedback (Q3 decided: GitHub Issues, pre-filled body with version/OS/platform, every platform). Privacy statement no longer says "anonymous" (random installation identifier). Parity matrix: `agentic/data/project-context/features/CR-SETTINGS-UX/validation/parity-matrix.md`. flutter test 458 pass; flutter analyze 0 errors, 0 warnings, 97 infos.
Real-device only (standard-UX pass): screen-reader announcement of merged rows and the selected section; bottom sheet with gesture navigation; focus ring visibility at OS high-contrast settings.

Next: user decides on commit and on the RELEASE gate; real-device checks (AC-11) per validation/qa.json; answers to Q2-Q8.

## Decisions
- 2026-11-21 (user), Q3: Send feedback goes to GitHub Issues (`https://github.com/macdipu/OpenReader/issues/new`), pre-filled body, every platform.
- 2026-11-21 (user), Q1: Firebase crash reporting and analytics are ALWAYS ON. No opt-in, no opt-out, no per-user permission, no Privacy Policy link. ST-06 is a disclosure statement only; startup keeps `setCrashlyticsCollectionEnabled(!kDebugMode)` and `setAnalyticsCollectionEnabled(!kDebugMode)`. The opt-out machinery added earlier in the working tree (native off-by-default flags, telemetry switches, TelemetryService, repository getters/setters) was removed. TECH-SPEC.md is frozen for the harness run and was not edited; where it describes telemetry switches, this decision supersedes it.
