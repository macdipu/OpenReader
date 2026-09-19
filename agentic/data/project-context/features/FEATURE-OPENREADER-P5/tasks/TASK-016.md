# Engineering Task

## Status
DONE (audited, no code change required) — 2026-09-19. Implements `SRS.md`/`ARCHITECTURE.md`'s first implementation slice, item (c): ODF-P5-05 offline/network audit. This is a verification item, not a fix — per `SRS.md`'s Error Flows note, no code changes were made because none were needed: BRD §15's offline mandate holds, verified by tracing every reachable call path rather than asserting it by design inspection alone (the gap this item exists to close, per `ARCHITECTURE.md`'s Non-Functional Requirements).

## Story
Offline/network audit (BRD Phase 5, hardening — Offline/network)

## Objective
ODF-P5-05: audit whether any bundled dependency (`dio`, `firebase_core`, `firebase_messaging`, `internet_connection_checker_plus`) is reachable from a document-viewer code path in violation of BRD §15's offline mandate.

## Method
Traced every import and call site of the four named packages across `lib/`, then traced upward from each usage to its actual call chain (not just "a file imports it") to confirm whether it is ever invoked, and if so, whether that path is reachable from document viewing/browsing at all — the audit's scope is broader than just "document-viewer", since a dependency reachable from *any* live path (e.g. app bootstrap) is a more fundamental finding than one scoped narrowly to readers.

## Findings

| Dependency | Reachable? | Detail |
|---|---|---|
| `dio` | **Not a dependency at all** | Zero references anywhere in `pubspec.yaml`, `pubspec.lock`, or `lib/`. `SRS.md`'s Functional Requirements table (ODF-P5-05 row) is stale on this point — likely written from an earlier state of the project or a template's own dependency list, not verified against this codebase before being listed. Corrected here rather than carried forward unverified into a future phase. |
| `firebase_core` / `firebase_messaging` | **Not reachable — dormant by explicit design** | `lib/app/flavours/app_flavour.dart:14-16` has both `Firebase.initializeApp()` and `NotificationService().init()` **commented out**, with an explicit `// TODO: Enable Firebase for production` marker. `NotificationService` (`lib/services/push_notification/notification_service.dart`), which wraps `FirebaseNotificationService`, is registered via `Get.lazyPut<NotificationService>(fenix: true)` in the same file but is never `Get.find`'d anywhere in `lib/` - so even the lazy registration never actually constructs it. No Firebase network call is possible in the current build under any user action, document-related or otherwise. |
| `internet_connection_checker_plus` | **Not reachable from any document path; reachable only from dead code** | `InternetConnectionService.hasConnection()` (`lib/services/utilities/internet_connection_service.dart`) is only ever called from `runTask()` (`lib/core/presentation/utils/task_runner.dart`), and only when that call passes `requiresNetwork: true`. Grepped every `runTask(` call site (45 across the codebase): the only two passing `requiresNetwork: true` are both in `VersionUpdateService.checkForUpdate`/`checkAndShowUpdate` (`lib/services/utilities/version_update_service.dart`) - an app-store update-check feature, unrelated to document viewing. Every `document_repository_impl.dart`/`favorite_repository_impl.dart`/`recent_repository_impl.dart` call site uses the default `requiresNetwork: false`, so `InternetConnectionService` is never invoked from any reader/library/favorites/recent code path. |

**Bonus finding: `VersionUpdateService` itself is dead code.** Grepped for `VersionUpdateService`/`AppVersionUpdate`/`app_version_update` across `lib/`: the class exists, is well-formed, and is the only place `requiresNetwork: true` appears - but nothing in the app ever constructs or calls it (no controller, binding, or view references `VersionUpdateService.instance`). Combined with the commented-out Firebase bootstrap and the unused `NotificationService`/`PreferenceCache` lazy registrations in the same file, this points to `app_flavour.dart` being leftover generic-app scaffolding (the `pubspec.yaml` comment "Weather Pulse - Charts / Animations / Fonts" above the charting/animation dependencies suggests OpenReader was built on top of a template app) rather than something built for OpenReader and later disabled. Not fixed here - this is dependency-reconciliation territory (ODF-P5-06's "each individually documented but never revisited together" framing fits exactly), not an offline-audit fix; flagged so ODF-P5-06 doesn't have to rediscover it.

## Conclusion
ODF-P5-05 is **satisfied**: no bundled dependency is reachable from a document-viewer (or any other live) code path in violation of BRD §15's offline mandate, as of this audit. This upgrades the offline posture from "asserted by design inspection" (every prior phase's SRS NFR) to "verified by call-path trace" for the first time, per `ARCHITECTURE.md`'s framing of this item. The finding is contingent on the current dormant state of `app_flavour.dart`'s commented-out Firebase bootstrap and unwired `VersionUpdateService` - if either is enabled in a future phase (the TODO explicitly anticipates this for "production"), this audit's conclusion no longer holds and BRD §15 would need re-verification against whatever network calls that enablement introduces.

## Acceptance Criteria
- ODF-P5-05: met — every named dependency's reachability traced to a concrete conclusion (not reachable, or reachable only from a call path outside document viewing), not merely asserted.

## Validation
No code changed, so no new `flutter analyze`/`flutter test` run was needed beyond the passing baseline already established in TASK-015 (152 pre-existing infos, 134/136 tests, same 2 pre-existing unrelated failures).

## References
- `SRS.md` ODF-P5-05, Unresolved Specification Question 1 (confirmed implementation order: item (c) after ODF-P5-03/04)
- `ARCHITECTURE.md` Non-Functional Requirements (this item's stated purpose: first project-wide audit vs. per-phase design-inspection assertion)
- `lib/app/flavours/app_flavour.dart`, `lib/core/presentation/utils/task_runner.dart`, `lib/services/utilities/version_update_service.dart`, `lib/services/utilities/internet_connection_service.dart`

## Out of Scope
- Removing or wiring up the dormant Firebase/notification/version-update scaffolding - a dependency-reconciliation decision (ODF-P5-06), not this audit's job.
- ODF-P5-06/08 — later items in the same confirmed implementation order, not started by this task.
