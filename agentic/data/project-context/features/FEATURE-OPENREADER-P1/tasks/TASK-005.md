# Engineering Task

## Status
DONE (commit `c9faa36`)

## Story
Onboarding & Storage Access

## Objective
Explain and request the storage access OpenReader needs before it can scan anything (BRD 9.2).

## Scope
`StorageAccessService`, `OnboardingController`/`OnboardingView`, `SplashController` routing decision, `AppSettingsRepository.hasCompletedOnboarding/setOnboardingComplete`, `AndroidManifest.xml` permissions.

## Dependencies
None (runs before TASK-001's scan can do anything useful, but doesn't depend on its code).

## Implementation Requirements
- Requests `MANAGE_EXTERNAL_STORAGE` first, falls back to `storage`; distinguishes denied vs. permanently-denied (→ "Open Settings").
- "Not Now" continues to the app shell in limited mode rather than blocking.
- On grant, fires `rescan()` unawaited so the transition to Home isn't gated on scan completion.

## Acceptance Criteria
- First launch reaches Onboarding; returning launch (after completion) skips straight to the app shell (verified live: `NAV:PUSH new=/splash` observed on-device via `adb logcat`, confirming router wiring; the subsequent onboarding→shell transition was not visually confirmed because the test device's lock screen blocked screen capture).
- Permanently-denied state shows a settings deep-link, not a dead end.

## Test Requirements
**Not met.** No instrumentation test drives the permission dialog paths.

## References
- `SRS.md` (Flows), `ARCHITECTURE.md` (Risk 1 — MANAGE_EXTERNAL_STORAGE)

## Out of Scope
The Play Store review implications of `MANAGE_EXTERNAL_STORAGE` — tracked as a pending ADR in `ARCHITECTURE.md`, not resolved by this task.
