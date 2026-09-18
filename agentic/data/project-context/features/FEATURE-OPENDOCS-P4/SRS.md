# SRS-OPENDOCS-P4: Text/CSV Readers and Platform Integration (BRD Phase 4)

## Status
**Implemented** (2026-09-18) — see `tasks/TASK-012.md`, the source of truth where implementation diverged from this scoping record (e.g. the large-file strategy landed on the simpler of the two options this document proposed).

## Scope
BRD §30 Phase 4: TXT reader, CSV reader, Android Open With integration, Share sheet, File Information — cross-checked against the per-format specs (§9.14 Text Reader, §9.15 CSV Reader) and Cross-Format Reader Requirements (§10).

Share sheet and File Information are **already fully implemented** (TASK-007, Phase 1) and format-agnostic — nothing new is needed for either; they are listed in BRD's Phase 4 deliverables but not in this phase's actual remaining work. Android Open With integration is `FEATURE-OPENDOCS-P1/tasks/TASK-009.md` (split out of TASK-007 on 2026-09-18), previously blocked on "at least one document reader existing" — PDF, Word, and Excel readers now exist (`FEATURE-OPENDOCS-P2`/`FEATURE-OPENDOCS-P3`), so TASK-009's blocker is now three-fifths cleared; this phase's TXT/CSV readers clear it further. This SRS scopes the two remaining net-new readers; TASK-009's own implementation is tracked in its existing task document, not duplicated here.

PowerPoint (`FEATURE-OPENDOCS-P3`, ODF-017/018) remains explicitly out of scope, blocked on a product decision not yet made (`FEATURE-OPENDOCS-P3/SRS.md` Unresolved Question 1) — Phase 4 does not depend on it, and TASK-009's exit criterion ("External-app open scenarios pass") does not require every category to have a reader, only that incoming intents for supported categories resolve correctly.

## Actors / Roles
Same single actor as every prior phase: the device owner, offline, no accounts (BRD §3).

## Functional Requirements
IDs reused from the BRD Requirement Traceability Matrix (§28) where they exist; new `ODF-P4-xx` IDs added for behavior §28 doesn't itemize individually.

| ID | Requirement | Status | Notes |
|---|---|---|---|
| ODF-019 | Read TXT offline | NOT DONE | P0. No third-party library needed — plain text display is a `Text`/`SelectableText` widget over file bytes; see `ARCHITECTURE.md` |
| ODF-020 | Read CSV as grid | NOT DONE | P1. Reuses `excel_plus`'s own CSV parser (`Excel.fromCsv`, already a dependency since `FEATURE-OPENDOCS-P3`) rather than adding a new CSV library or hand-rolling one — see `ARCHITECTURE.md` |
| ODF-008 | Restore reading position (TXT/CSV) | PARTIAL → this phase completes it for these formats | Same generic `reading_position` JSON column and `RecentRepository.getPosition()`/`markOpened()` reused from `FEATURE-OPENDOCS-P2/TASK-010`, no migration |
| ODF-P4-01 | TXT: adjustable text size, line wrap toggle, full screen | NOT DONE | BRD §9.14 Features |
| ODF-P4-02 | TXT: search with highlighting | NOT DONE | BRD §9.14 Features; same UX shape as every other reader's search (query → count → highlight → prev/next) |
| ODF-P4-03 | TXT: encoding detection "where feasible" | NOT DONE, scoped narrowly | BRD §9.14 explicitly hedges this with "where feasible" — see Non-Functional Requirements for what this phase actually attempts |
| ODF-P4-04 | CSV: row/column grid with header-row detection, horizontal+vertical scroll | NOT DONE | BRD §9.15 Features; reuses the Excel reader's grid widget (extracted to be shared) rather than a second hand-built grid |
| ODF-P4-05 | CSV: search values, delimiter detection "where feasible" | NOT DONE | BRD §9.15 Features |
| n/a | Full-screen, rotation, favorite toggle, share, file info, Open With for TXT/CSV readers | NOT DONE | BRD §10 (cross-format) — reuses `DocumentInteractionController`, not reimplemented, same as every prior reader |

## Non-Functional Requirements
- BRD §14 performance: "TXT open: near-instant for normal files" is the one format-specific performance row in the entire BRD — worth calling out since it's a concrete, testable target unlike most other rows. Large-text-file handling (BRD §9.14 Corner Cases: "Very large text file," "Extremely long line without breaks") needs lazy/windowed rendering to hold this, not a naive "read the whole file into one `Text` widget" approach for arbitrarily large files — flagged as a real design constraint, not assumed solved by using a `Text` widget.
- BRD §15 offline mandate: trivially satisfied — no library involved for TXT, and `excel_plus`'s CSV parsing is already local/offline (verified in `FEATURE-OPENDOCS-P3`).
- Encoding: BRD's own "where feasible" hedge is taken literally here — this phase's plan (see `ARCHITECTURE.md`) is a UTF-8-first-with-Latin-1-fallback heuristic, not full charset auto-detection (e.g. BOM-sniffing beyond UTF-8/UTF-16 BOMs, or a statistical detector). A genuinely unknown/exotic encoding renders as replacement characters or mojibake rather than correctly - accepted as a documented limitation, matching BRD's own hedge rather than over-building.

## Data Rules
- No schema migration needed, same reasoning as every prior phase: `recent_documents.reading_position` is already a generic JSON `TEXT` column.
- BRD §16 doesn't define a distinct `ReaderPosition` shape for TXT beyond reusing "Word/TXT" (`scroll_offset`, `anchor` if available) — this phase's TXT reader controls its own `Text`/scrollable widget directly (unlike the Word reader, which depends on `docx_file_viewer`'s opaque internals), so a real pixel `scroll_offset` **and** restore both work here — no equivalent gap to the one `FEATURE-OPENDOCS-P3/TASK-011` documented for Word.
- BRD §16 doesn't define a `ReaderPosition` shape for CSV at all (only PDF/Word-TXT/Excel/PowerPoint are listed) — this phase proposes reusing Excel's shape (`row`, `column`, `horizontal_offset`, `vertical_offset`; no `sheet_index` since CSV has one implicit sheet), since the CSV reader reuses the Excel reader's grid widget directly.

## Interfaces
- `DocumentInteractionController.openDocument(DocumentModel document)` gains two more category branches (`text`, `csv`), following the exact pattern every prior format used.
- Two new reader modules under `lib/features/`: `text_reader`, `csv_reader`, matching the controller/view/binding shape every prior reader used.
- **A new shared grid widget**, factored out of `FEATURE-OPENDOCS-P3`'s `ExcelReaderView._Grid` (currently file-private) so the CSV reader can reuse it instead of duplicating ~150 lines of scroll-sync/frozen-header logic. This is a refactor of existing code, not new design — flagged here so it isn't done silently mid-implementation without a record of why.

## Flows
### Normal Flow
Same shape as every prior reader: open → content renders → position saved on exit/background (debounced) → reopening restores it. For CSV specifically: BRD §9.15's header-row detection means the first row renders as a header row (frozen, bold) rather than as an ordinary data row, by default assuming the file has one — see Unresolved Question 1 for what happens when it doesn't.

### Alternate Flows
- TXT search: query → highlight → prev/next, same UX as every other reader.
- CSV search: same shape as Excel's cell search (`FEATURE-OPENDOCS-P3/TASK-011`), reused directly since it operates on the same parsed-rows model.

### Error Flows
BRD §13's generic rows apply directly (corrupted file, missing file, permission lost). TXT-specific: BRD §9.14 Corner Case "Binary file renamed as `.txt`" — decoding binary data as text typically produces garbage or a decode exception; this phase's plan is to catch the decode failure and show the existing generic "This document may be damaged or incomplete." message rather than rendering mojibake as if it were valid content.

## Traceability
See the Functional Requirements table above.

## Unresolved Specification Questions
1. **CSV header-row detection has no reliable general algorithm.** BRD §9.15 lists "Header detection" as a feature without specifying how. A common heuristic (first row's cell types differ from the column's subsequent rows - e.g. all-text header over a numeric column) is easy to get wrong on all-text data (BRD's own corner case: "Empty rows," "Uneven row lengths" make this harder still). Proposed default: treat the first row as a header unless the file is empty, with no smarter heuristic attempted - simple, predictable, and wrong only in the minority case where a CSV genuinely has no header row (which then just renders as a bolded first data row, a cosmetic-only mistake, not a data-loss one). Needs confirmation this is acceptable before implementation, or a decision to attempt something smarter.
2. **CSV delimiter detection**: BRD says "if feasible." `excel_plus`'s `CsvConfig` supports an explicit delimiter (comma/semicolon/tab presets) but does not auto-detect one from file content. Proposed default: assume comma, with semicolon/tab as a fallback only if comma-splitting produces exactly one column across every row (a cheap, narrow heuristic) - not a general auto-detector. Needs the same confirm-or-decide treatment as Question 1.
3. **TXT encoding detection scope** (see Non-Functional Requirements) - UTF-8-first-with-Latin-1-fallback only, not full charset sniffing. Flagging for explicit sign-off rather than assuming "where feasible" means "as much as reasonably possible" without a stated ceiling.
4. **Very large TXT/CSV files** (BRD §9.14/9.15 Corner Cases: large text file, 1M+ row CSV) - this phase's architecture needs to decide whether to lazy-load/paginate or accept a hard size ceiling with a "too large" message (BRD §13 already has "This document is too large to render safely on this device." for exactly this). Not decided in this SRS; `ARCHITECTURE.md` proposes an approach but it is unverified against a real large-file test corpus, the same posture every prior phase has taken for its own large-file risk.

## References
- `agentic/data/project-context/features/OpenDocs_BRD_v1.0.md` §9.14, §9.15, §10, §12, §13, §14, §15, §16, §28 (ODF-019/020), §30 (Phase 4)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P3/SRS.md`, `ARCHITECTURE.md`, `tasks/TASK-011.md` (process and reuse pattern this phase follows, including the Excel grid this phase reuses)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P1/tasks/TASK-009.md` (Open From Other Apps - tracked separately, referenced not duplicated)
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/core/data/repositories/recent_repository_impl.dart`, `lib/features/excel_reader/presentation/excel_reader_view.dart` (the grid to be shared)
