# FEATURE-OPENREADER-P5: Hardening (BRD Phase 5)

## Request and scope

User asked to "Start phase 5" after Phase 4 (Text/CSV readers + Open From Other Apps) shipped and passed verification. This document is a genuine pre-implementation scoping pass, matching P2/P3/P4's own process — no hardening code exists yet.

Unlike P2–P4, Phase 5 is not "build a new reader": BRD §30 lists it as Large-file optimization, Low-memory handling, Security hardening, Corrupted-file handling, Accessibility pass, Performance testing, Offline/network audit, Dependency audit — an audit-and-fix pass against everything already built in Phases 1–4. A dedicated research pass consolidated every already-documented risk/gap from every prior phase's own ARCHITECTURE/TASK docs into `SRS.md`'s Functional Requirements table; nothing there is a newly invented finding.

Classification: proposed grouping of independently shippable hardening items (no cross-item dependency), split into an "actionable now" bucket (code/config fixes verifiable without a device) and a "blocked on environment" bucket (needs a real Android device/emulator, CI, or a large-file test corpus — none of which has existed in any phase of this project).

## Requirements and evidence

| ID | Acceptance criterion | Bucket | Status | Evidence |
|---|---|---|---|---|
| ODF-030 | Remain responsive with large files | Large-file / Performance | NOT VERIFIED (no large-file corpus) — but the total cold-boot blocker found on 2026-09-19 is FIXED, see below | [TASK-013.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-013.md) |
| ODF-P5-01 | Stop bundling `.env` as a readable asset | Security | DONE (2026-09-19) — compile-time constants, `flutter_dotenv` removed | commit `2aeae27` |
| ODF-P5-02 | Storage-access distribution-channel decision | Security | DECIDED (2026-09-19) — Play Store, general release, special-access declaration | `ADR-OPENREADER-storage-access.md` |
| ODF-P5-03/04 | Office ZIP/security + corrupted-file hardening | Security / Corrupted-file | DONE (2026-09-19) — `ZipSafetyGuard` | [TASK-015.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-015.md) |
| ODF-P5-05 | Offline/network audit | Offline/network | DONE (2026-09-19) — satisfied, no violation | [TASK-016.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-016.md) |
| ODF-P5-06 | Dependency reconciliation | Dependency audit | NOT DONE, scoped | Same |
| ODF-P5-07 | Add CI config | Dependency audit / Security | DONE (2026-09-19) — `.github/workflows/ci.yml` | [TASK-013.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-013.md) |
| ODF-P5-08 | Accessibility semantics baseline | Accessibility | NOT DONE, fresh scope (no prior mention anywhere) | Same |
| ODF-P5-09/10/11 | Large-file corpus, performance profiling, native/device verification | Large-file / Performance | BLOCKED on environment | Same |
| ODF-P5-12 | Low-memory TXT reader tradeoff | Low-memory | Documented, not fixed this pass | Same |

## Design boundaries

No new architectural layer. Every "actionable now" item reuses an existing dependency (Flutter's own `Semantics` API, the already-transitive `archive` package for ZIP-safety checks) or removes a runtime dependency (`flutter_dotenv`, once `.env` moves to compile-time injection) — see `ARCHITECTURE.md` Alternatives Considered. **No new dependency, no ADR** for this phase, same posture P4 took.

`SRS.md`'s Unresolved Question 1 proposes an implementation order for the actionable items (`.env`/CI first, then Office security hardening, then offline audit, dependency reconciliation, and the accessibility pass last as the largest single item) — not yet confirmed.

Three items are explicitly out of this phase's reach rather than silently dropped: ODF-P5-02 (a product decision, not engineering, mirroring the still-open PowerPoint question from `FEATURE-OPENREADER-P3`), and ODF-P5-09/10/11 (large-file corpus, performance profiling, native/device verification — all blocked on an Android SDK/emulator/CI environment that has never existed in this project). `ARCHITECTURE.md` Risks documents what a future device/CI-equipped session would need to actually close these, rather than attempting a lower-fidelity substitute that could be mistaken for real verification.

## Validation and handoff

Scoping confirmed 2026-09-19 — user resolved all four `SRS.md` Unresolved Specification Questions: implementation order accepted as proposed; ODF-P5-02 decided (Play Store, general release, special-access declaration path — recorded in `ADR-OPENREADER-storage-access.md`); ODF-P5-09/10/11 documented-only (no simulated device verification); ODF-P5-08 accessibility baseline confirmed as `Semantics`/`flutter test` coverage.

First implementation slice (a) is done: ODF-P5-01 (`.env` fix, commit `2aeae27`) and ODF-P5-07 (CI config, [TASK-013.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-013.md)), both verified via `flutter analyze` (0 errors/warnings) and `flutter test` (122/124 — 2 pre-existing failures unrelated to this slice, a Windows-path-separator bug in `FileScannerService._nameOf()` (renamed from `DocumentScannerService`, see TASK-014), documented in TASK-013 as a new latent-bug finding, not fixed).

**Severe finding, found and fixed same session:** the user asked to also run the app on a real Android emulator — the first time this has happened in this project's history. It surfaced a genuine total-blocker: the app never got past its splash screen. Initial investigation suspected `FlutterSecureStorage`'s Android-Keystore migration (a real, separate improvement was made regardless — `AppSettingsRepositoryImpl` now uses plain `shared_preferences` instead, since none of its values are sensitive), but that was a red herring. The actual root cause: `SplashView` never reads `GetView.controller`, and `SplashBinding` registered `SplashController` with `Get.lazyPut` (only constructed on first `Get.find()`) — so `SplashController` was never instantiated at all, and its `onInit()` (which drives bootstrap-and-navigate) never ran. Fixed by switching to eager `Get.put` in `SplashBinding`, matching how `ThemeController`/`LocaleController` are already registered in `app.dart`. Verified end-to-end on the emulator: splash → onboarding → app shell (Home/Files/Favorites/Settings) all render correctly. Full diagnostic trail in [TASK-013.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-013.md). `flutter analyze`/`flutter test` unaffected (same baseline as before).

**Full manual QA pass, same session, once booting worked:** the user asked to walk every implemented feature on the emulator to confirm they actually work. Found and fixed two more real bugs — see [TASK-014.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-014.md) for full detail:
- **CSV reader was completely broken** (100% of CSVs, not content-dependent): `Isolate.run(() => xls.Excel.fromCsv(...))` always threw ("object is unsendable"), because the resulting `Excel` object graph isn't isolate-sendable — a wrong assumption in the original implementation that `Excel.decodeBytesAsync`'s isolate-safety extended to `Excel.fromCsv` too. Fixed by parsing synchronously instead (small regression on large-CSV UI-thread offload, documented, not re-solved).
- **Favorites tab could silently go stale**: `DocumentInteractionController` (documented as the single shared source of truth for favorite state) was registered `fenix: true`, letting GetX dispose and lazily recreate it — `FavoritesController`'s one-time `ever()` subscription to its `favoriteIds` then permanently stopped receiving updates. Fixed via `permanent: true` registration plus an explicit reload on Favorites-tab-select as a second guard.
- All 5 implemented readers (PDF, Word, Excel, CSV, Text) now verified working end-to-end with real files, plus Home, All Files, Search, Favorites, and Settings' "Refresh file index". A minor cosmetic duplicate-entry artifact (a stray private-cache-path document) was found but not root-caused — flagged for later, not fixed.

Second implementation slice (b) is done: ODF-P5-03/04 (Office ZIP/security hardening — [TASK-015.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-015.md)). A shared `ZipSafetyGuard` rejects an oversized/malicious ZIP before either Office reader decompresses it, reusing BRD §13's existing "too large" message; a fixture shaped like a real password-protected file (Office's OLE2 compound-file signature — real encrypted files aren't ZIPs at all) confirmed the existing generic corrupted-file message fires instead of a crash or hang. `flutter analyze` (0 errors/warnings, same 152 pre-existing infos) and `flutter test` (134/136 — same 2 pre-existing failures, plus 10 new passing tests) both verified.

Third implementation slice (c) is done: ODF-P5-05 offline/network audit — [TASK-016.md](../project-context/features/FEATURE-OPENREADER-P5/tasks/TASK-016.md). Audit-only, no code change: traced every call site of `dio`/`firebase_core`/`firebase_messaging`/`internet_connection_checker_plus`. Result: no violation of BRD §15. `dio` isn't even a dependency (a stale SRS reference, now corrected); Firebase is dormant behind a commented-out bootstrap call with an explicit "enable for production" TODO; the network-connectivity checker is reachable only from `VersionUpdateService`, which turned out to be dead code no controller ever calls — flagged for ODF-P5-06 rather than fixed here, since that's a dependency-reconciliation decision, not an offline-audit one.

## Process note

Routed through the same scoping approach as `FEATURE-OPENREADER-P2`/`P3`/`P4` — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
