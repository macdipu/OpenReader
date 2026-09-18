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

**PDF library decision: resolved 2026-09-18.** The product owner ruled out any paid dependency ("I don't want to pay anything"), which rules out `syncfusion_flutter_pdfviewer` outright. Re-examining the remaining free options found that `pdfrx` — initially ruled out in the first scoping pass because its latest release needs Flutter ≥3.47.0 — has an older release, `2.4.8`, that requires only Flutter ≥3.41.0 (compatible with this project's pinned 3.44.4) and already includes real text search and native (non-web-only) password support, both confirmed via its own CHANGELOG. Verified for real, not just reasoned about: `pdfrx: 2.4.8` was added to `pubspec.yaml` and `flutter pub get`/`flutter analyze` were run — resolved cleanly, 0 new errors/warnings, then reverted pending approval. See `ARCHITECTURE.md`'s Alternatives Considered for the full comparison (including why `pdfx`'s password support doesn't work on Android/iOS at all, and `flutter_pdfview`'s search is still just a roadmap item). [ADR-OPENDOCS-pdf-library](../project-context/features/FEATURE-OPENDOCS-P2/adr/ADR-OPENDOCS-pdf-library.md) records this decision — drafted, Status: Proposed, not yet approved.

## Validation and handoff

No implementation code has been written. The one exception, done deliberately and reverted before this document was written: `pdfrx: 2.4.8` was temporarily added to `pubspec.yaml` to verify it actually resolves against this project's ~60 other dependencies and that `flutter analyze` stays clean — it does, and the change was then backed out so nothing lands before the ADR is approved. Next steps, in order:
1. Approve (or amend) `ADR-OPENDOCS-pdf-library.md`.
2. Decide TOC/bookmarks/hyperlinks in-or-out for this phase's first slice (`SRS.md` Unresolved Question 2).
3. Task-breakdown pass once 1–2 are resolved — the story split sketched in `ARCHITECTURE.md`'s Risks section (core rendering/navigation → reading-position persistence → thumbnails → search → password flow → cross-format actions) is a reasonable default but not yet a committed Sprint Plan.

## Process note

Routed through `technical-architecture-planner`-equivalent reasoning directly in this session, consistent with how `FEATURE-OPENDOCS-P1`'s TASK-007 architecture pass was done — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
