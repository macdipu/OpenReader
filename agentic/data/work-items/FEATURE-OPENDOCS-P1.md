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
| ODF-005 | Open document from another app | DONE (2026-09-18) | [TASK-009](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-009.md) (split from TASK-007, then implemented the same day once PDF/Word/Excel/Text/CSV readers existed — `receive_sharing_intent` intent-filters, real logic unit-tested; PowerPoint excluded, real device delivery unverified — see TASK-009's own delta) |
| ODF-021, ODF-023 | Missing-file, lost-permission handling | DONE, including every reader | [SRS](../project-context/features/FEATURE-OPENDOCS-P1/SRS.md) — shared `_verifyStillAccessible()` guard from TASK-007, reused unchanged by every reader added since (`FEATURE-OPENDOCS-P2/P3/P4`) |
| ODF-008 | Restore reading position | DONE for PDF/Excel/Text/CSV; write-only (no restore) for Word | Now that readers exist: `FEATURE-OPENDOCS-P2/tasks/TASK-010.md`, `FEATURE-OPENDOCS-P3/tasks/TASK-011.md` (documents the Word gap — `docx_file_viewer` exposes no scroll-control API), `FEATURE-OPENDOCS-P4/tasks/TASK-012.md` |
| ODF-030 | Responsive with large files | UNVERIFIED | No test corpus run; each reader phase's own ARCHITECTURE.md carries this same open risk forward |
| n/a | Bounded automated test coverage | IMPLEMENTED, growing every phase | [TASK-008](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-008.md) (33 tests) → TASK-007 (+17) → TASK-010 (+14) → TASK-011 (+26) → TASK-012 (+27) → TASK-009 (+6) = 124 total, `flutter test` passing |

## Design boundaries

Reuse the project's existing clean-architecture layering, `BaseController`/`Failure`/`Either` error convention, and GetX routing — no new architectural pattern was introduced (see `ARCHITECTURE.md`, "Existing Patterns / Components Reused"). One genuinely new decision was made and flagged rather than silently settled: `MANAGE_EXTERNAL_STORAGE` for broad document discovery, which carries Play Store review risk (`ARCHITECTURE.md` Risk 1) and needs an ADR before production.

## Validation and handoff

`flutter analyze`: 0 errors, 0 warnings introduced (168 pre-existing infos in untouched files remain). App was built, installed, and launched on a physical Android device (CPH2269, Android 11); reached `/splash` with no crash or exception in logs. Onboarding→Home visual confirmation was not completed because the test device's own lock screen (user's PIN/pattern) blocked further screen capture — not a code defect.

TASK-008 adds 33 passing scanner, SQLite repository, and Home/All Files widget tests. The user approved that implementation scope on 2026-09-17. Current analysis exits 0 with 158 existing infos and no errors/warnings. No UAT or release approval has been recorded (`SPRINT.md`). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL` — this phase should not be read as release-ready.

TASK-007 (2026-09-18) adds Share/File Information/Open With/missing-file/lost-permission handling: 17 new tests (50 total), `flutter analyze` still 0 errors/warnings (158 pre-existing infos, same baseline). A Flutter 3.44.4 SDK was installed into the working environment specifically to run these checks for real rather than leave them unverified. No Android SDK/emulator/device was available in this environment, so the native happy-path (real share sheet / Open With chooser actually opening) was not exercised — that remains a device-verification item, consistent with Phase 1's own physical-device verification above. See `TECH-SPEC.md` "TASK-007 implementation delta" for two corrections found only once the actual code/dependencies were inspected (no manifest `FileProvider` needed; the onboarding disclosure screen already existed) and a GetX-snackbar test-draining quirk discovered while writing the new tests.

TASK-009 (2026-09-18, same day `FEATURE-OPENDOCS-P2/P3/P4` shipped their readers) closes ODF-005 last: `receive_sharing_intent` intent-filters for every category with a reader, `IncomingDocumentResolver`'s decision logic unit-tested (6/6), `DocumentRepository.indexDocument()` added after reading `app_database.dart`'s schema directly and confirming a foreign-key constraint would otherwise make a reader's own `markOpened()` call throw for an unindexed incoming file. `flutter test`: 124/124 passing project-wide. Real Android intent delivery remains a device-verification item; see TASK-009's own implementation delta for the full writeup, including a `flutter_test`-environment limitation found (not a defect in this task) that blocks only `IncomingIntentService`'s own widget-level tests.

## Process note

The original implementation predated enforced routing. The repository now records `local-harness` mode with Claude hooks in installation.json. TASK-008 uses the explicit runtime CLI task protocol in Codex; timing, technical approval, command permissions and scoped results are recorded. See TASK-008 for run identifiers and evidence.
