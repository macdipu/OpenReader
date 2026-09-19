# FEATURE-OPENREADER-P4: Text/CSV Readers and Platform Integration (BRD Phase 4)

## Request and scope

User asked to "start" (scoping Phase 4) after `FEATURE-OPENREADER-P3` (Word/Excel readers) shipped and passed verification, following the recommendation to move to Phase 4 rather than wait on the still-undecided PowerPoint question. This document is a genuine pre-implementation scoping pass, matching P2/P3's own process — no TXT/CSV reader code exists yet.

Classification: proposed `STORY_TASK` grouping (two independently testable readers), consistent with P2/P3. Scope: BRD §30 Phase 4 — TXT reader, CSV reader. Share sheet and File Information (also listed in BRD's Phase 4 deliverables) are already fully implemented since Phase 1 (TASK-007) and need no new work here. Android Open With integration (`FEATURE-OPENREADER-P1/tasks/TASK-009.md`) is tracked in its own existing task document, not duplicated in this one.

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-019 | Read TXT offline | DONE, test-verified (real file, incl. non-UTF-8 and binary-detection cases) | [TASK-012](../project-context/features/FEATURE-OPENREADER-P4/tasks/TASK-012.md) |
| ODF-020 | Read CSV as grid | DONE, test-verified (real file, incl. quoted-comma and multi-line-quoted-value corner cases) | Same — reuses `excel_plus`'s CSV parser and the extracted shared grid widget |
| ODF-008 | Restore reading position (TXT/CSV) | DONE for both formats, save **and** restore | [TASK-012](../project-context/features/FEATURE-OPENREADER-P4/tasks/TASK-012.md) — unlike Word (`FEATURE-OPENREADER-P3`), the Text reader owns its own scrolling directly, so no restore gap |
| ODF-P4-01…05 | Text size/wrap/full-screen, TXT search, encoding handling, CSV grid/header-detection/search | DONE | Same |
| n/a | Favorite/Share/Open With/File Info inside each reader | DONE | Reuses `DocumentInteractionController` unchanged, same pattern as every prior reader |

## Design boundaries

Reuses the established clean-architecture layering, `BaseController`/GetX conventions, and `DocumentInteractionController` wholesale. `DocumentInteractionController.openDocument()` gains two more branches (`text`, `csv`). `DocumentCategory` already has the right enum values — confirmed by reading `document_category.dart`, no model change needed.

**No new dependency, no ADR.** Unlike P2/P3, this phase's research (documented in `ARCHITECTURE.md`) concluded neither reader needs a new library: TXT uses Flutter's own text widgets over raw file bytes, and CSV reuses `excel_plus`'s existing CSV parser (`Excel.fromCsv`) — already a project dependency since `FEATURE-OPENREADER-P3`, already handling BRD's hardest CSV corner cases (quoted commas, multi-line quoted values) as part of its own tested surface. The CSV reader also reuses the Excel reader's grid widget rather than rebuilding one, via a planned extraction of `ExcelReaderView`'s currently-file-private `_Grid` into a shared widget.

Three items are explicitly flagged as open decisions, not silently assumed, in `SRS.md`'s Unresolved Specification Questions: CSV header-row detection (no general algorithm exists; proposes a simple "assume first row is header" default), CSV delimiter detection (proposes comma-first with a narrow semicolon/tab fallback heuristic, not general auto-detection), and TXT encoding detection's scope (UTF-8-first/Latin-1-fallback only, not full charset sniffing) — all matching BRD's own "where feasible" hedging rather than over-building past what was asked for.

One real, verified risk carried into `ARCHITECTURE.md`: `excel_plus`'s CSV parsing path has no isolate-friendly async entry point (confirmed by reading its source), unlike its `.xlsx` path's `decodeBytesAsync`. **Fixed during implementation**, not just documented: `CsvReaderController` wraps the parse in its own `Isolate.run`, verified safe against `Excel.decodeBytesAsync`'s own `Isolate.exit`-based implementation and test-confirmed working.

## Validation and handoff

**Implemented 2026-09-18** ("Start implementation" — see [TASK-012](../project-context/features/FEATURE-OPENREADER-P4/tasks/TASK-012.md) for the as-built design and its delta). `flutter analyze`: 0 errors/warnings (158 pre-existing infos, unchanged baseline). `flutter test`: 118/118 passing (91 pre-existing + 27 new). Both readers' tests build and parse real files exercising BRD's own named hard corner cases directly (quoted commas, multi-line quoted CSV values, non-UTF-8 text, a binary payload renamed `.txt`) — no native binary dependency for either format, so this is stronger verification than fixture-only tests, matching `FEATURE-OPENREADER-P3`'s own pattern.

The two CSV heuristics and TXT encoding scope proposed in `SRS.md`'s Unresolved Questions 1–3 were implemented exactly as proposed (defaults only, no smarter detection attempted) since no request for more came back. The large-file strategy (`SRS.md` Unresolved Question 4) landed on the simpler of the two proposed approaches: a hard size ceiling with BRD's existing "too large" message, not disk-backed windowed reading — see TASK-012's delta for what that does and doesn't cover.

TASK-009 (Open From Other Apps) shipped the same day (`FEATURE-OPENREADER-P1/tasks/TASK-009.md`), once this phase's readers cleared its last blocker — no open item remains from this phase's side other than the PowerPoint gap already tracked in `FEATURE-OPENREADER-P3`.

## Process note

Routed through the same scoping approach as `FEATURE-OPENREADER-P2`/`P3` — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
