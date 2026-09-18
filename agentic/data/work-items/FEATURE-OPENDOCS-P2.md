# FEATURE-OPENDOCS-P2: PDF Reader (BRD Phase 2)

## Request and scope

User asked to "start scoping the PDF reader" as the next step after TASK-007 (Share/File Information/Open With) shipped. This document is a genuine pre-implementation scoping pass, not a backfill — no PDF reader code exists yet.

Classification: proposed `STORY_TASK` (multiple independently testable capabilities — rendering/navigation, reading-position persistence, thumbnails, search, password flow — large enough to warrant story-level grouping, same reasoning `FEATURE-OPENDOCS-P1/SPRINT.md` used for Phase 1). Scope: BRD §30 Phase 2 — PDF rendering, zoom, scroll/page modes, search, thumbnails, jump to page, password flow, reading position. TOC/bookmarks and hyperlink navigation (BRD §9.10) are proposed as deferred, not silently dropped — see `SRS.md` Unresolved Specification Questions.

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-011 | Read PDF offline | DONE (native rendering unverified — see delta) | [TASK-010](../project-context/features/FEATURE-OPENDOCS-P2/tasks/TASK-010.md) |
| ODF-012 | Search PDF text | DONE (highlighting unverified against a real PDF — see delta) | [TASK-010](../project-context/features/FEATURE-OPENDOCS-P2/tasks/TASK-010.md) |
| ODF-008 | Restore reading position (PDF) | DONE, test-verified | [TASK-010](../project-context/features/FEATURE-OPENDOCS-P2/tasks/TASK-010.md) — no schema migration needed, reused the existing `reading_position` JSON column |
| ODF-P2-01…06 | View modes, zoom, thumbnails, jump-to-page, password flow, search+highlight | DONE (2 view modes shipped, not 3 — see delta) | [TASK-010](../project-context/features/FEATURE-OPENDOCS-P2/tasks/TASK-010.md) |
| n/a | Favorite/Share/Open With/File Info inside the reader | DONE | [TASK-010](../project-context/features/FEATURE-OPENDOCS-P2/tasks/TASK-010.md) — reuses `DocumentInteractionController` and TASK-007's File Information route unchanged |

## Design boundaries

Reuses Phase 1's clean-architecture layering, `BaseController`/GetX conventions, and — critically — TASK-007's `DocumentInteractionController` (favorite/share/open-with/accessibility-guard) wholesale rather than reimplementing per-reader. `DocumentInteractionController.openDocument()` (`document_interaction_controller.dart:79`) is the exact integration seam: this phase adds a category dispatch to it, replacing the current stub for `DocumentCategory.pdf` only.

**PDF library decision: resolved 2026-09-18.** The product owner ruled out any paid dependency ("I don't want to pay anything"), which rules out `syncfusion_flutter_pdfviewer` outright. Re-examining the remaining free options found that `pdfrx` — initially ruled out in the first scoping pass because its latest release needs Flutter ≥3.47.0 — has an older release, `2.4.8`, that requires only Flutter ≥3.41.0 (compatible with this project's pinned 3.44.4) and already includes real text search and native (non-web-only) password support, both confirmed via its own CHANGELOG. Verified for real, not just reasoned about: `pdfrx: 2.4.8` was added to `pubspec.yaml` and `flutter pub get`/`flutter analyze` were run — resolved cleanly, 0 new errors/warnings, then reverted pending approval. See `ARCHITECTURE.md`'s Alternatives Considered for the full comparison (including why `pdfx`'s password support doesn't work on Android/iOS at all, and `flutter_pdfview`'s search is still just a roadmap item). [ADR-OPENDOCS-pdf-library](../project-context/features/FEATURE-OPENDOCS-P2/adr/ADR-OPENDOCS-pdf-library.md) records this decision — drafted, Status: Proposed, not yet approved.

## Validation and handoff

**Implemented 2026-09-18** ("Approve it, start implementation" — the ADR was accepted and the reader was built directly, in one pass, rather than through the multi-task breakdown sketched below; see [TASK-010](../project-context/features/FEATURE-OPENDOCS-P2/tasks/TASK-010.md) for the as-built design, the implementation delta, and verified gaps). `flutter analyze`: 0 errors/warnings (158 pre-existing infos, unchanged baseline). `flutter test`: 65/65 passing (51 pre-existing + 14 new). Native PDF rendering itself is not verified in this environment (no PDFium available) — an explicit, documented gap, not claimed as done.

Remaining open items, unchanged from the original scoping:
1. Decide TOC/bookmarks/hyperlinks in-or-out for a later slice (`SRS.md` Unresolved Question 2) — still deferred, not resolved by TASK-010.
2. TASK-009 (Open From Other Apps) — its "no reader exists" blocker is now partially cleared for PDF files, but the task itself is unimplemented.

## Process note

Routed through `technical-architecture-planner`-equivalent reasoning directly in this session, consistent with how `FEATURE-OPENDOCS-P1`'s TASK-007 architecture pass was done — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
