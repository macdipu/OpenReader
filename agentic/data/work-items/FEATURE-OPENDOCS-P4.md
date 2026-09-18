# FEATURE-OPENDOCS-P4: Text/CSV Readers and Platform Integration (BRD Phase 4)

## Request and scope

User asked to "start" (scoping Phase 4) after `FEATURE-OPENDOCS-P3` (Word/Excel readers) shipped and passed verification, following the recommendation to move to Phase 4 rather than wait on the still-undecided PowerPoint question. This document is a genuine pre-implementation scoping pass, matching P2/P3's own process — no TXT/CSV reader code exists yet.

Classification: proposed `STORY_TASK` grouping (two independently testable readers), consistent with P2/P3. Scope: BRD §30 Phase 4 — TXT reader, CSV reader. Share sheet and File Information (also listed in BRD's Phase 4 deliverables) are already fully implemented since Phase 1 (TASK-007) and need no new work here. Android Open With integration (`FEATURE-OPENDOCS-P1/tasks/TASK-009.md`) is tracked in its own existing task document, not duplicated in this one.

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-019 | Read TXT offline | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P4/SRS.md), [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P4/ARCHITECTURE.md) — no new dependency needed |
| ODF-020 | Read CSV as grid | NOT DONE (scoped) | Same — reuses `excel_plus`'s CSV parser and the Excel reader's grid widget (to be extracted/shared) |
| ODF-008 | Restore reading position (TXT/CSV) | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P4/SRS.md) — no schema migration needed, reuses `RecentRepository.getPosition`/`markOpened` |
| ODF-P4-01…05 | Text size/wrap/full-screen, TXT search, encoding handling, CSV grid/header-detection/search | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P4/SRS.md), [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P4/ARCHITECTURE.md) |
| n/a | Favorite/Share/Open With/File Info inside each reader | NOT DONE (scoped, low risk) | Reuses `DocumentInteractionController` unchanged, same pattern as every prior reader |

## Design boundaries

Reuses the established clean-architecture layering, `BaseController`/GetX conventions, and `DocumentInteractionController` wholesale. `DocumentInteractionController.openDocument()` gains two more branches (`text`, `csv`). `DocumentCategory` already has the right enum values — confirmed by reading `document_category.dart`, no model change needed.

**No new dependency, no ADR.** Unlike P2/P3, this phase's research (documented in `ARCHITECTURE.md`) concluded neither reader needs a new library: TXT uses Flutter's own text widgets over raw file bytes, and CSV reuses `excel_plus`'s existing CSV parser (`Excel.fromCsv`) — already a project dependency since `FEATURE-OPENDOCS-P3`, already handling BRD's hardest CSV corner cases (quoted commas, multi-line quoted values) as part of its own tested surface. The CSV reader also reuses the Excel reader's grid widget rather than rebuilding one, via a planned extraction of `ExcelReaderView`'s currently-file-private `_Grid` into a shared widget.

Three items are explicitly flagged as open decisions, not silently assumed, in `SRS.md`'s Unresolved Specification Questions: CSV header-row detection (no general algorithm exists; proposes a simple "assume first row is header" default), CSV delimiter detection (proposes comma-first with a narrow semicolon/tab fallback heuristic, not general auto-detection), and TXT encoding detection's scope (UTF-8-first/Latin-1-fallback only, not full charset sniffing) — all matching BRD's own "where feasible" hedging rather than over-building past what was asked for.

One real, verified risk carried into `ARCHITECTURE.md`: `excel_plus`'s CSV parsing path has no isolate-friendly async entry point (confirmed by reading its source), unlike its `.xlsx` path's `decodeBytesAsync` — a very large CSV (BRD's own "1M+ rows" corner case) would need the implementation to wrap the parse call in its own `Isolate.run`/`compute`, not assume the library handles it.

## Validation and handoff

No implementation code has been written; this pass is research and documentation only, matching how P2's and P3's own first scoping passes worked. Next steps, in order:
1. Confirm (or amend) the two CSV heuristics and TXT encoding scope proposed in `SRS.md`'s Unresolved Questions 1–3 — small decisions, but worth explicit sign-off before building against them.
2. Decide the large-file strategy for both formats (`SRS.md` Unresolved Question 4) before implementation, since it affects the reader's core architecture (windowed rendering vs. a size ceiling), not just a detail to patch in later.
3. Task-breakdown pass once 1–2 are resolved — likely TXT and CSV as their own tasks (the Excel-grid extraction is a shared prerequisite for CSV specifically, not for TXT).
4. Once TXT/CSV ship, TASK-009 (Open From Other Apps) has no remaining "no reader exists" blocker for any category this app plans to ship a reader for other than PowerPoint — worth revisiting TASK-009's own implementation at that point.

## Process note

Routed through the same scoping approach as `FEATURE-OPENDOCS-P2`/`P3` — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
