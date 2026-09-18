# FEATURE-OPENDOCS-P2: PDF Reader (BRD Phase 2)

## Request and scope

User asked to "start scoping the PDF reader" as the next step after TASK-007 (Share/File Information/Open With) shipped. This document is a genuine pre-implementation scoping pass, not a backfill — no PDF reader code exists yet.

Classification: proposed `STORY_TASK` (multiple independently testable capabilities — rendering/navigation, reading-position persistence, thumbnails, search, password flow — large enough to warrant story-level grouping, same reasoning `FEATURE-OPENDOCS-P1/SPRINT.md` used for Phase 1). Scope: BRD §30 Phase 2 — PDF rendering, zoom, scroll/page modes, search, thumbnails, jump to page, password flow, reading position. TOC/bookmarks and hyperlink navigation (BRD §9.10) are proposed as deferred, not silently dropped — see `SRS.md` Unresolved Specification Questions.

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-011 | Read PDF offline | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P2/SRS.md) |
| ODF-012 | Search PDF text | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P2/SRS.md) — depends on library choice |
| ODF-008 | Restore reading position (PDF) | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P2/SRS.md) — no schema migration needed, confirmed against `app_database.dart` |
| ODF-P2-01…06 | View modes, zoom, thumbnails, jump-to-page, password flow, search+highlight | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P2/SRS.md), [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P2/ARCHITECTURE.md) |
| n/a | Favorite/Share/Open With/File Info inside the reader | NOT DONE (scoped, low risk) | [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P2/ARCHITECTURE.md) — reuses `DocumentInteractionController` and TASK-007's File Information route unchanged, no new work beyond wiring |

## Design boundaries

Reuses Phase 1's clean-architecture layering, `BaseController`/GetX conventions, and — critically — TASK-007's `DocumentInteractionController` (favorite/share/open-with/accessibility-guard) wholesale rather than reimplementing per-reader. `DocumentInteractionController.openDocument()` (`document_interaction_controller.dart:79`) is the exact integration seam: this phase adds a category dispatch to it, replacing the current stub for `DocumentCategory.pdf` only.

**One blocking decision, not yet made:** which PDF rendering library to use. `ARCHITECTURE.md`'s Alternatives Considered compares four options, verified directly against their current pub.dev listings/licenses (not from memory, since three were updated after this assistant's training cutoff):
- `pdfx` and `flutter_pdfview` — MIT, free, but rendering-only; search/thumbnails/password UI would be custom-built.
- `syncfusion_flutter_pdfviewer` — covers nearly the full BRD §9.10 feature list out of the box, but requires either qualifying for Syncfusion's Community License (org revenue < $1M/year and fewer than 5 developers) or a paid commercial license.
- `pdfrx` — ruled out for now: requires Flutter ≥3.47.0, newer than this project's pinned 3.44.4 (`.fvmrc`).
- `native_pdf_view` — ruled out: unmaintained since 2022.

This is a genuine business/licensing decision this scoping pass does not make on its own, per AGENTS.md's "never invent missing business rules" — mirrors how `ADR-OPENDOCS-storage-access` was flagged rather than silently settled for TASK-007. Recommend an ADR once the product owner has weighed in on the licensing question.

## Validation and handoff

Nothing has been implemented. No code changes, no dependency added, no test run. This is scoping only, per the user's explicit request ("start scoping the PDF reader," not "implement"). Next steps, in order:
1. Product owner decides the PDF-library/licensing question (`SRS.md` Unresolved Question 1).
2. Draft and approve `ADR-OPENDOCS-pdf-library.md` accordingly.
3. Decide TOC/bookmarks/hyperlinks in-or-out for this phase's first slice (`SRS.md` Unresolved Question 2).
4. Task-breakdown pass once 1–3 are resolved — the story split sketched in `ARCHITECTURE.md`'s Risks section (core rendering/navigation → reading-position persistence → thumbnails → search → password flow → cross-format actions) is a reasonable default but not yet a committed Sprint Plan.

## Process note

Routed through `technical-architecture-planner`-equivalent reasoning directly in this session, consistent with how `FEATURE-OPENDOCS-P1`'s TASK-007 architecture pass was done — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
