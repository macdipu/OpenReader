# SRS-OPENDOCS-P2: PDF Reader (BRD Phase 2)

## Status
Draft. Scoping only — no implementation exists yet. This is a pre-implementation proposal, unlike P1's SRS which was backfilled after the fact.

## Scope
BRD §30 Phase 2 (PDF Reader), scoped to BRD's own named Phase 2 deliverables: PDF rendering, zoom, scroll/page modes, search, thumbnails, jump to page, password flow, reading position (§30) — cross-checked against the fuller PDF Reader Screen spec (§9.10) and Cross-Format Reader Requirements (§10). Two §9.10 items are **explicitly deferred**, not silently dropped: table of contents/bookmarks and internal/external hyperlink navigation — neither is named in Phase 2's own deliverable list, and both add real scope (a TOC data model, a link-target-resolution layer) beyond what a first PDF reader needs to hit BRD's own Phase 2 exit criterion ("PDF feature acceptance criteria pass using PDF test corpus"). Recommend a follow-up task once Phase 2's core ships, tracked below as an Unresolved Specification Question rather than assumed in scope.

Word/Excel/PowerPoint/Text/CSV readers (§9.11–9.15) are explicitly out of scope (BRD Phase 3/4).

## Actors / Roles
Same single actor as Phase 1: the device owner, offline, no accounts (BRD §3).

## Functional Requirements
IDs reused from the BRD Requirement Traceability Matrix (§28) where they exist; new IDs (`ODF-P2-xx`) added for PDF-specific behavior §28 doesn't itemize individually (search, thumbnails, password, view modes are all folded into ODF-011/012 there).

| ID | Requirement | Status | Notes |
|---|---|---|---|
| ODF-011 | Read PDF offline | NOT DONE | Core rendering; no network involved by construction (reuses the offline-only posture already established in Phase 1) |
| ODF-012 | Search PDF text | NOT DONE | Depends on the chosen library exposing text extraction — see `ARCHITECTURE.md` Alternatives |
| ODF-008 | Restore reading position | PARTIAL → this phase completes it for PDF | Schema already supports it (`recent_documents.reading_position`, `RecentRepository.markOpened(readingPosition:)`) — no migration needed, confirmed by reading `app_database.dart` |
| ODF-P2-01 | Single-page / continuous-vertical / horizontal-page view modes | NOT DONE | BRD §9.10 Core Features |
| ODF-P2-02 | Pinch-to-zoom, double-tap zoom, fit width, fit page | NOT DONE | BRD §9.10 |
| ODF-P2-03 | Page thumbnails (navigation) | NOT DONE | BRD §9.10, named in Phase 2's own deliverable list |
| ODF-P2-04 | Jump to page (indicator + slider/entry) | NOT DONE | BRD §9.10 |
| ODF-P2-05 | Password-protected PDF flow (prompt, wrong-password error, unlock) | NOT DONE | BRD §9.10 Scenario C, BRD §13 "Wrong PDF password" |
| ODF-P2-06 | Text search with highlighting and prev/next navigation | NOT DONE | BRD §9.10 Scenario B, §12.3 corner cases (no text layer, blank query, Unicode/RTL, very high match count) |
| n/a | Full-screen, rotation, favorite toggle, share, file info, Open With for the PDF reader | NOT DONE | BRD §10 (cross-format) — **reuses `DocumentInteractionController.toggleFavorite`/`shareDocument`/`openWithExternalApp` and the File Information route already built in TASK-007**, not reimplemented per reader |

Out of scope for this SRS (see Unresolved Specification Questions): TOC/bookmarks, internal/external hyperlink navigation.

## Non-Functional Requirements
- BRD §14 performance targets apply directly: small PDF open under 2s, cached recent open under 1s "where renderer permits," 60fps scrolling target, lazy loading / bounded memory for large files. None of these are measurable until a library is chosen and a first build exists — flagged, not assumed met.
- BRD §15 offline mandate: the PDF library must not require network access for rendering (all four alternatives evaluated in `ARCHITECTURE.md` render locally via PDFium or a native platform view; none phone home for basic rendering).
- BRD §12.5 security corner cases relevant here: password-protected PDF, unsupported encryption type, malicious malformed document. "ZIP bomb" and "path traversal in packaged Office files" are Office-specific (§12.2), not applicable to PDF's own container format.

## Data Rules
- No schema migration needed: `recent_documents.reading_position` is already a generic JSON `TEXT` column (`app_database.dart:57`), and `RecentDocumentModel.readingPosition`/`RecentRepository.markOpened()` already accept an arbitrary `Map<String, Object?>` (confirmed by reading `recent_document_model.dart` and `recent_repository_impl.dart`) — BRD §16's suggested PDF `ReaderPosition` fields (`page_number`, `zoom_mode`, `scroll_offset`) slot in as map keys without touching `AppDatabase._version`.
- BRD §16's suggested `RecentDocument.reader_type` field does not exist in the actual Phase 1 schema and is not proposed here either — `documents.category`/`extension` already determine which reader a document opens with, so a redundant `reader_type` column would duplicate that without adding information.

## Interfaces
- `DocumentInteractionController.openDocument(DocumentModel document)` (`lib/core/presentation/controllers/document_interaction_controller.dart:79`) is the existing integration seam — it already runs the ODF-021/023 accessibility guard and calls `RecentRepository.markOpened()`; this phase replaces its current stub body ("reader is not part of this build yet") with real navigation to the PDF reader route for `DocumentCategory.pdf`, and leaves the stub in place for every other category until Phase 3/4.
- A new `PdfReaderRepository`-shaped interface (or, if the chosen library's own controller is a sufficient abstraction, no new repository at all — an architecture decision, not assumed here) for whatever page/zoom/search state needs a persistence round-trip beyond what the library's own controller holds in memory.

## Flows
### Normal Flow
BRD §11 Scenario 1 exactly: tap PDF → reader opens at page 1 (or the remembered page) → user reads/scrolls → app records position on close/background → reopening resumes at the recorded page.

### Alternate Flows
- Password-protected PDF: BRD §9.10 Scenario C (prompt → correct password opens → incorrect password shows "Incorrect password." per §13 and allows retry).
- Search: BRD §9.10 Scenario B (query → result count → highlighted matches → prev/next navigation); "No searchable text found." (§13) when the PDF has no text layer (scanned-image-only PDF, §12.3).

### Error Flows
BRD §13's PDF-relevant rows apply directly: corrupted file ("This document may be damaged or incomplete." → Close/Try another app), out-of-memory protection for huge files ("This document is too large to render safely on this device." → Close), plus the already-implemented missing-file/permission-lost messages from TASK-007's shared guard, which fire before the reader route is ever entered.

## Traceability
See the Functional Requirements table above.

## Unresolved Specification Questions
1. **PDF rendering library is not yet chosen** — this blocks everything else in this SRS. See `ARCHITECTURE.md` Alternatives Considered and ADR Recommendation; the leading open-source option (`pdfx`) provides rendering only and would need custom engineering for search/thumbnails/password UI, while the leading full-featured option (`syncfusion_flutter_pdfviewer`) covers nearly the whole BRD §9.10 list out of the box but requires either qualifying for Syncfusion's revenue/team-size-gated Community License or a paid commercial license — a business decision, not invented here.
2. **TOC/bookmarks and hyperlink navigation** (BRD §9.10) are proposed as deferred/out-of-scope for this phase's first slice (see Scope) — needs explicit confirmation this is acceptable, or a decision to pull them in now, before Sprint Planning finalizes the task breakdown.
3. **Full-text search's underlying capability depends entirely on library choice** (Unresolved Question 1) — some PDFium-based options expose page-level text extraction, others don't without extra work; this cannot be resolved independently of the library decision.
4. BRD §14 performance targets are unverified-in-principle until a library exists to profile against (same posture Phase 1 took for ODF-030) — not a gap unique to this phase, but worth restating so it isn't assumed solved by picking any particular library.

## References
- `agentic/data/project-context/features/OpenDocs_BRD_v1.0.md` §5, §6.5, §9.10, §10, §11 (Scenario 1), §12.2–12.6, §13, §14, §15, §16, §28 (ODF-008/011/012), §30 (Phase 2)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P1/SRS.md`, `ARCHITECTURE.md`, `TECH-SPEC.md` (existing patterns this phase reuses)
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/core/data/local/app_database.dart`, `lib/core/data/repositories/recent_repository_impl.dart`
