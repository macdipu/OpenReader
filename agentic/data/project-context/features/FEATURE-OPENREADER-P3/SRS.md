# SRS-OPENREADER-P3: Office Readers (BRD Phase 3)

## Status
**Word and Excel: implemented** (2026-09-18) — see `tasks/TASK-011.md`, the source of truth where implementation diverged from this scoping record. **PowerPoint: still Draft/unscoped for real** — blocked on Unresolved Question 1 below, not yet decided.

## Scope
BRD §30 Phase 3 (Office Readers): DOCX reader, XLSX reader, PPTX reader, legacy format support "where feasible," search within supported Office readers, reading-state restoration — cross-checked against the fuller per-format specs (§9.11 Word, §9.12 Excel, §9.13 PowerPoint) and Cross-Format Reader Requirements (§10).

Three formats, evaluated together in one SRS/ARCHITECTURE pass (unlike P2's single-format scope) because Phase 3's own BRD deliverable list bundles them and the library landscape for each is different enough that the comparison is more useful side by side than split into three separate documents.

TXT/CSV readers (§9.14–9.15) remain explicitly out of scope (BRD Phase 4), as does anything from Phase 2 already shipped (`FEATURE-OPENREADER-P2`).

## Actors / Roles
Same single actor as Phase 1/2: the device owner, offline, no accounts (BRD §3).

## Functional Requirements
IDs reused from the BRD Requirement Traceability Matrix (§28) where they exist; new `ODF-P3-xx` IDs added for behavior §28 doesn't itemize individually.

| ID | Requirement | Status | Notes |
|---|---|---|---|
| ODF-013 | Read DOCX offline | NOT DONE | Core rendering; see `ARCHITECTURE.md` Alternatives — real, verified library options exist, unlike PPTX |
| ODF-014 | Search DOCX text | NOT DONE | Depends on chosen library exposing search — `docx_file_viewer` (leading candidate) has it built in |
| ODF-015 | Read XLSX offline | NOT DONE | Parsing is well covered (`excel_plus`); grid UI is custom, same "library gives primitives, OpenReader builds the widget" pattern as P2's PDF thumbnails |
| ODF-016 | Search spreadsheet cells | NOT DONE | Built on the same parsed cell data as ODF-015; no library provides this, first-party logic |
| ODF-017 | Read PPTX offline | NOT DONE — **real gap, not just unimplemented** | No verified free Flutter library renders PPTX content natively with real fidelity as of this scoping pass (see `ARCHITECTURE.md` Alternatives and Unresolved Question 1). This is not the same kind of "not done yet" as ODF-013/015 |
| ODF-018 | Search slide text | NOT DONE | Blocked on ODF-017's library gap |
| ODF-008 | Restore reading position (Word/Excel/PowerPoint) | PARTIAL → this phase extends it | Schema already generic (`recent_documents.reading_position`, JSON), same as P2 — no migration, but BRD §16's per-format `ReaderPosition` shapes differ (scroll offset vs. sheet/row/column vs. slide index) and must each be handled by the matching reader's own save/restore logic, not shared code |
| ODF-P3-01 | DOCX formatting fidelity: paragraphs, headings, bold/italic/underline, lists, tables, images, headers/footers, hyperlinks | NOT DONE | BRD §9.11 Core Features |
| ODF-P3-02 | XLSX grid: sheet tabs, cell values/formatting, merged cells, frozen rows/columns, horizontal+vertical scroll, jump-to-cell on search | NOT DONE | BRD §9.12 Core Features |
| ODF-P3-03 | PPTX slide rendering: text, images, shapes, tables, backgrounds, swipe navigation, thumbnail strip, jump-to-slide | NOT DONE, gated on Unresolved Question 1 | BRD §9.13 Core Features |
| ODF-P3-04 | Legacy format support (`.doc`, `.xls`, `.ppt`) "where feasible" | NOT DONE, likely partial by design | BRD §30 says "where feasible," not "required" — see Unresolved Question 2 |
| ODF-P3-05 | Password-protected Office file handling | NOT DONE, **unverified whether any candidate library supports it at all** | BRD §12.5/§9.11–13 corner cases list this per format; none of the researched libraries' documentation mentions encryption support (see `ARCHITECTURE.md` Risks) |
| n/a | Full-screen, rotation, favorite toggle, share, file info, Open With for all three readers | NOT DONE | BRD §10 (cross-format) — reuses `DocumentInteractionController` exactly as P2's PDF reader does, not reimplemented per reader |

## Non-Functional Requirements
- BRD §14 performance targets apply: no specific Office-reader row exists, but the general "scrolling 60fps," "lazy loading; bounded memory," and "large files" targets apply directly to XLSX's "100,000+ rows" and DOCX's "very large table" corner cases (§9.11–12 Corner Cases).
- BRD §15 offline mandate: ruled out any candidate that requires internet or a WebView-backed proprietary rendering service during this pass's own research (see `ARCHITECTURE.md` — `in_app_file_view` and `power_file_viewer_v2` were both disqualified on this basis alone, independent of licensing).
- BRD §12.5 security corner cases: "malicious malformed document," "ZIP bomb," and "path traversal in packaged Office files" are specifically called out for Office formats (unlike PDF) because DOCX/XLSX/PPTX are all ZIP containers — the parsing library's ZIP handling matters, not just its document-model correctness. Not audited line-by-line in this scoping pass (same posture P2 took for PDFium).

## Data Rules
- No schema migration needed, same reasoning as P2: `recent_documents.reading_position` is already a generic JSON `TEXT` column and `RecentRepository.markOpened(readingPosition:)` already accepts an arbitrary map.
- BRD §16's suggested per-format `ReaderPosition` shapes become each reader's own map keys:
  - Word/TXT: `scroll_offset`, `anchor` (if the chosen library exposes one — `docx_file_viewer`'s scroll/search API needs checking during implementation for a stable anchor concept beyond a raw pixel offset, which would drift if the document reflows on a different device).
  - Excel: `sheet_index`, `row`, `column`, `horizontal_offset`, `vertical_offset`.
  - PowerPoint: `slide_index`.
- `RecentRepository.getPosition()` (added in `FEATURE-OPENREADER-P2/TASK-010`) is reused as-is — it already returns an untyped `Map<String, Object?>`, so no change needed for Word/Excel/PowerPoint to read back their own differently-shaped position map.

## Interfaces
- `DocumentInteractionController.openDocument(DocumentModel document)` gains three more category branches (`word`, `excel`, `powerpoint`), each dispatching to its own reader route, exactly like the `pdf` branch `FEATURE-OPENREADER-P2` added. The stub message remains for whatever categories still have no reader (text/csv, until Phase 4).
- Three new reader modules under `lib/features/`, mirroring `pdf_reader`'s controller/view/binding shape: `word_reader`, `excel_reader`, `ppt_reader` (naming to match `DocumentCategory`'s existing enum values — needs confirming against `document_category.dart` during implementation, not assumed here).
- A parsing-layer seam per format, analogous to how `PdfReaderController` never calls `pdfrx` types outside itself and `pdf_reader_view.dart`: whichever library is chosen for DOCX/XLSX should not leak its own types into `DocumentInteractionController` or other screens.

## Flows
### Normal Flow
BRD §11 Scenario 4 (spreadsheet) and Scenario 2 (DOCX from another app, though the intent-handling half of that scenario is `TASK-009`, not this phase): open → format-specific reader shows content → position saved on exit/background → reopening restores it.

### Alternate Flows
- Search: BRD §9.11/§9.12/§9.13 each have their own "Search" feature list entry; behavior should match P2's PDF search UX (query → highlight → prev/next) wherever the underlying library supports it — for PPTX this is blocked on Unresolved Question 1.
- Excel-specific: BRD §9.12 Scenario B (formula workbook) — display the stored/cached result, do not attempt recalculation unless the chosen library's engine explicitly supports it as a feature, not a side effect.

### Error Flows
BRD §13's generic rows apply (corrupted file, unsupported format, missing file, permission lost — all already implemented via the shared guard and error-message pattern from TASK-007/`FEATURE-OPENREADER-P2`). Two BRD §13 rows are Office-specific and not yet exercised by any existing code: "Unsupported Office feature" (`Some document elements may not be displayed correctly.` → Continue) and the corrupted-file message reused verbatim for BRD's own PPTX-specific Scenario 7 wording (`Unable to open this presentation. The file may be damaged or incomplete.` — a presentation-specific variant of the generic corrupted-file message, not a new error code).

## Traceability
See the Functional Requirements table above.

## Unresolved Specification Questions
1. **No verified free Flutter library renders PPTX content natively with real fidelity.** `microsoft_viewer` (MIT) renders *something* for PPTX but its own README calls itself "very basic" with no search and "minimum formatting"; `universal_file_viewer` (MIT, actively maintained) explicitly falls back to opening PPTX in an external app rather than rendering it inline at all (v0.1.7, per its own documented notes). This is a real, verified finding, not an assumption — see `ARCHITECTURE.md` Alternatives. Three paths forward, none decided here: (a) ship `microsoft_viewer`'s basic PPTX support and accept the fidelity/search gap against ODF-017/018 as P0 requirements; (b) build a first-party minimal PPTX renderer directly on OOXML primitives (`archive` + `xml` packages, parsing slide XML for text/shape/image placement ourselves — a materially larger, PDF-thumbnail-style "primitives, not a library" undertaking); (c) defer PPTX specifically to a later slice and rely on the existing Open With fallback in the meantime, treating BRD's Phase 3 "Office compatibility matrix completed" exit criterion as satisfied by DOCX+XLSX with PPTX explicitly logged as a known gap. Needs an explicit decision, not a default.
2. **Legacy format support** (`.doc`, `.xls`, `.ppt` — pre-OOXML binary formats) — BRD §30 only requires this "where feasible." None of the libraries researched in this pass (`docx_file_viewer`, `excel_plus`, `microsoft_viewer`) document binary legacy-format support; `excel_plus`'s own README claims `.xls` (Excel 97-2003) reading is supported, which would need direct verification before being relied on. Needs a decision on whether legacy formats are in this phase's first slice or a documented follow-up, mirroring how P2 deferred TOC/bookmarks.
3. **Password-protected Office file support is unverified for every candidate library.** Unlike `pdfrx` (which has a confirmed, working `PasswordProvider` mechanism), none of `docx_file_viewer`'s, `excel_plus`'s, or `microsoft_viewer`'s documentation mentions encryption/password handling at all — its absence from otherwise-detailed READMEs is itself the signal, not proof of absence, but treated as "assume unsupported until proven otherwise" per this project's own verification standard. If a password-protected Office file is opened and the library can't parse it, the existing generic "This document may be damaged or incomplete." error message would fire — which is technically BRD-compliant (§13's corrupted-file row) but not as precise as PDF's dedicated password flow. Needs a decision: accept the generic error as sufficient for Phase 3's first slice, or scope a real password flow once a library that supports it (if any) is found.
4. BRD §14 performance targets remain unverified-in-principle until a working build exists to profile against, same posture P1 (ODF-030) and P2 already carry forward.

## References
- `agentic/data/project-context/features/OpenReader_BRD_v1.0.md` §9.11–9.13, §10, §11 (Scenarios 2, 4, 7), §12, §13, §14, §15, §16, §28 (ODF-013…018), §30 (Phase 3)
- `agentic/data/project-context/features/FEATURE-OPENREADER-P2/SRS.md`, `ARCHITECTURE.md`, `tasks/TASK-010.md` (process and reuse pattern this phase follows)
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/core/data/repositories/recent_repository_impl.dart`, `lib/core/domain/repositories/recent_repository.dart`
