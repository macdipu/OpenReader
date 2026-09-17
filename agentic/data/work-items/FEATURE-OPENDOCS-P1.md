# FEATURE-OPENDOCS-P1: OpenDocs Phase 1 (Foundation)

## Request and scope

User requested "start development" against the OpenDocs BRD (`agentic/data/project-context/features/OpenDocs_BRD_v1.0.md`), then confirmed "Full Phase 1 Foundation" when asked to scope the starting slice. **This document is a backfill**: implementation (commit `c9faa36`) was written before any SDLC artifact existed, because the work was routed directly to ad-hoc implementation instead of through `agentic-sdlc-orchestrator` and its specialist skills. That gap was identified and this backfill was requested to restore traceability per AGENTS.md rule 14.

Classification: `STORY_TASK` (see `SPRINT.md` for rationale). Scope: BRD §30 Phase 1 — local document index, storage-access flow, and the non-reader shell (Home, All Files, Search, Recents, Favorites, Settings). Explicitly excludes all reader screens (Phase 2/3) and Open With/Share/File Info (Phase 4).

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-001 | Local document discovery | DONE | [SRS](../project-context/features/FEATURE-OPENDOCS-P1/SRS.md), [TASK-001](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-001.md) |
| ODF-002/003/004 | Search, filter, sort | DONE | [TASK-002](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-002.md) |
| ODF-006 | Recent history | DONE | [TASK-003](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-003.md) |
| ODF-007 | Favorites | DONE | [TASK-004](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-004.md) |
| ODF-025/026 | Offline, non-destructive | DONE | [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P1/ARCHITECTURE.md) |
| ODF-027/028/029 | Theme, clear recents, clear cache | DONE | [TASK-006](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-006.md) |
| ODF-005, ODF-009, ODF-010 | Open With, Share, File Info | NOT DONE | [TASK-007](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-007.md) (backlog) |
| ODF-008, ODF-021, ODF-023 | Reading position, missing-file, lost-permission handling | PARTIAL | [SRS](../project-context/features/FEATURE-OPENDOCS-P1/SRS.md) |
| ODF-030 | Responsive with large files | UNVERIFIED | No test corpus run |
| n/a | Automated test coverage | NOT DONE | [TASK-008](../project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-008.md) (backlog) |

## Design boundaries

Reuse the project's existing clean-architecture layering, `BaseController`/`Failure`/`Either` error convention, and GetX routing — no new architectural pattern was introduced (see `ARCHITECTURE.md`, "Existing Patterns / Components Reused"). One genuinely new decision was made and flagged rather than silently settled: `MANAGE_EXTERNAL_STORAGE` for broad document discovery, which carries Play Store review risk (`ARCHITECTURE.md` Risk 1) and needs an ADR before production.

## Validation and handoff

`flutter analyze`: 0 errors, 0 warnings introduced (168 pre-existing infos in untouched files remain). App was built, installed, and launched on a physical Android device (CPH2269, Android 11); reached `/splash` with no crash or exception in logs. Onboarding→Home visual confirmation was not completed because the test device's own lock screen (user's PIN/pattern) blocked further screen capture — not a code defect.

No automated test suite exists for any of this phase's code (TASK-008, backlog). No human approval or UAT has been recorded (`SPRINT.md`). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL` — this phase should not be read as release-ready.

## Process note

Root cause of the backfill: this project runs in `instruction-only` mode (no `installation.json`, no `.claude/settings.json` hooks) — nothing enforces routing through the orchestrator/skills automatically. This is a candidate reason to enable `local-harness` mode's hook wiring going forward (see `agentic/kit/config/hooks.json`), so the next work item routes through the pipeline instead of relying on the agent's judgment call each time.
