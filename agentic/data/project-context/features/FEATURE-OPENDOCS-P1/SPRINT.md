# Sprint Plan (Retroactive) — FEATURE-OPENDOCS-P1

## Status
Backfilled. This is a record of how the completed work *would have* been sequenced, not a forward commitment — no dates, capacity, or human sprint-commitment approval exist for it (per `sprint-planner`'s "do not infer sprint commitment" boundary).

## Affected Module
`app` (see `agentic/data/project-context/modules/app.yaml`) — single module, no cross-team split needed.

## Work-Item-Level Classification
**STORY_TASK.** Not `EPIC_STORY_TASK`: everything in this phase is one team, one module, no architecture-shaping cross-service dependency. Not `TASK_ONLY`: six independently testable capabilities (index/scan, search/filter/sort, recents, favorites, onboarding, settings) are large enough to warrant story-level grouping, per `work-item-level-classifier`'s decision factors (multiple coherent outcomes, moderate risk from the storage-access permission).

## Stories → Tasks (delivery order actually used)
1. **Onboarding & Storage Access** — TASK-005 (must exist before anything can scan)
2. **Local Document Index & Scanning** — TASK-001 (everything else reads from this)
3. **Search, Filter, Sort** — TASK-002 (depends on 2)
4. **Recent History** — TASK-003 (depends on 2)
5. **Favorites** — TASK-004 (depends on 2)
6. **Settings** — TASK-006 (depends on 2, 3)

Parallelizable: 3, 4, 5, 6 have no dependency on each other once 2 exists — a real sprint could have split them across parallel lanes; this backfill was built sequentially by a single agent, so that parallelism was never exercised.

## Not Included In This Sprint (Backlog)
- TASK-007 (Share/File-Info/Open-With/permission-loss robustness) — blocked on an architecture decision (storage-access ADR).
- TASK-008 (automated test coverage) — should not have been deferred past this sprint; flagged as the sprint's biggest process gap.

## UAT Target
None set. No human has reviewed or approved this phase; `context_status: PARTIAL` in `project.yaml` reflects that.

## Explicitly Not Claimed
- No capacity, velocity, or date data exists for this project, so none is invented here.
- No sprint commitment or stakeholder approval is implied by this document's existence — it documents sequencing only.

## References
- `agentic/data/project-context/features/OpenDocs_BRD_v1.0.md` §30 (Phase 1 exit criteria)
- `TASK-001.md` through `TASK-008.md`
