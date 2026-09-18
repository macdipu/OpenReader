# FEATURE-OPENDOCS-P1: OpenDocs Phase 1 (Foundation)

## Request and scope

User requested "start development" against the OpenDocs BRD (`agentic/data/project-context/features/OpenDocs_BRD_v1.0.md`), then confirmed "Full Phase 1 Foundation" when asked to scope the starting slice. **This document is a backfill**: implementation (commit `c9faa36`) was written before any SDLC artifact existed, because the work was routed directly to ad-hoc implementation instead of through `agentic-sdlc-orchestrator` and its specialist skills. That gap was identified and this backfill was requested to restore traceability per AGENTS.md rule 14.

Classification: `STORY_TASK` (see `SPRINT.md` for rationale). Scope: BRD §30 Phase 1 — local document index, storage-access flow, and the non-reader shell (Home, All Files, Search, Recents, Favorites, Settings). Explicitly excludes all reader screens (Phase 2/3); Open With/Share/File Info (Phase 4) was originally excluded too, but Share and File Info (ODF-009/010) were pulled forward and implemented via TASK-007 on 2026-09-18 — Open With *to* another app for a document OpenDocs already discovered went with them (a `DocumentListTile` action, distinct from ODF-005's *incoming* intent, which remains excluded and tracked as TASK-009).

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-001 | Local document discovery | DONE | [SRS](../project-context/features/FEATURE-OPENDOCS-P1/SRS.md), [TASK-001](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-001.md) |
| ODF-002/003/004 | Search, filter, sort | DONE | [TASK-002](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-002.md) |
| ODF-006 | Recent history | DONE | [TASK-003](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-003.md) |
| ODF-007 | Favorites | DONE | [TASK-004](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-004.md) |
| ODF-025/026 | Offline, non-destructive | DONE | [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P1/ARCHITECTURE.md) |
| ODF-027/028/029 | Theme, clear recents, clear cache | DONE | [TASK-006](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-006.md) |
| ODF-009, ODF-010 | Share, File Info | DONE (2026-09-18) | [TASK-007](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-007.md) (IMPLEMENTED — `flutter analyze` 0 errors/warnings, `flutter test` 50/50; [TECH-SPEC](../project-context/features/FEATURE-OPENDOCS-P1/TECH-SPEC.md#task-007-implementation-delta-2026-09-18) has the delta and what remains device-verification-only) |
| ODF-005 | Open document from another app | NOT DONE | [TASK-009](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-009.md) (backlog; split from TASK-007 on 2026-09-18 — blocked on a document reader existing, per BRD §7.7/§30, independent of the storage-access ADR) |
| ODF-021, ODF-023 | Missing-file, lost-permission handling | DONE for open/share/info/open-with (2026-09-18) | [SRS](../project-context/features/FEATURE-OPENDOCS-P1/SRS.md) — shared `_verifyStillAccessible()` guard in TASK-007; still nothing for a reader, since none exists |
| ODF-008 | Restore reading position | PARTIAL | [SRS](../project-context/features/FEATURE-OPENDOCS-P1/SRS.md) — unchanged, needs a reader |
| ODF-030 | Responsive with large files | UNVERIFIED | No test corpus run |
| n/a | Bounded automated test coverage | IMPLEMENTED | [TASK-008](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-008.md) (33 tests), extended by TASK-007 (+17 tests, 50 total) |

## Design boundaries

Reuse the project's existing clean-architecture layering, `BaseController`/`Failure`/`Either` error convention, and GetX routing — no new architectural pattern was introduced (see `ARCHITECTURE.md`, "Existing Patterns / Components Reused"). One genuinely new decision was made and flagged rather than silently settled: `MANAGE_EXTERNAL_STORAGE` for broad document discovery, which carries Play Store review risk (`ARCHITECTURE.md` Risk 1) and needs an ADR before production.

## Validation and handoff

`flutter analyze`: 0 errors, 0 warnings introduced (168 pre-existing infos in untouched files remain). App was built, installed, and launched on a physical Android device (CPH2269, Android 11); reached `/splash` with no crash or exception in logs. Onboarding→Home visual confirmation was not completed because the test device's own lock screen (user's PIN/pattern) blocked further screen capture — not a code defect.

TASK-008 adds 33 passing scanner, SQLite repository, and Home/All Files widget tests. The user approved that implementation scope on 2026-09-17. Current analysis exits 0 with 158 existing infos and no errors/warnings. No UAT or release approval has been recorded (`SPRINT.md`). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL` — this phase should not be read as release-ready.

TASK-007 (2026-09-18) adds Share/File Information/Open With/missing-file/lost-permission handling: 17 new tests (50 total), `flutter analyze` still 0 errors/warnings (158 pre-existing infos, same baseline). A Flutter 3.44.4 SDK was installed into the working environment specifically to run these checks for real rather than leave them unverified. No Android SDK/emulator/device was available in this environment, so the native happy-path (real share sheet / Open With chooser actually opening) was not exercised — that remains a device-verification item, consistent with Phase 1's own physical-device verification above. See `TECH-SPEC.md` "TASK-007 implementation delta" for two corrections found only once the actual code/dependencies were inspected (no manifest `FileProvider` needed; the onboarding disclosure screen already existed) and a GetX-snackbar test-draining quirk discovered while writing the new tests.

## Process note

The original implementation predated enforced routing. The repository now records `local-harness` mode with Claude hooks in installation.json. TASK-008 uses the explicit runtime CLI task protocol in Codex; timing, technical approval, command permissions and scoped results are recorded. See TASK-008 for run identifiers and evidence.
