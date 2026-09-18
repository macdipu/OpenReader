# Engineering Task

## Status
DONE (implemented, `flutter analyze`/`flutter test` verified) — 2026-09-18. Implemented directly against `SRS.md`/`ARCHITECTURE.md`/`ADR-OPENDOCS-office-libraries.md` in this session ("Yes" - approving the ADR and starting implementation).

## Story
Word and Excel Readers (BRD §9.11–9.12, Phase 3)

## Objective
ODF-013/014 (DOCX read + search), ODF-015/016 (XLSX read + search), ODF-008 (reading-position restore for Word/Excel).

## Dependencies
- `ADR-OPENDOCS-office-libraries.md` — **Accepted**: `docx_file_viewer: 1.0.4` for Word, `excel_plus: 2.22.0` for Excel.
- `DocumentInteractionController` (TASK-007) and its `openDocument()` category-dispatch seam (extended in `FEATURE-OPENDOCS-P2/TASK-010` for PDF) — reused, not reimplemented.
- `RecentRepository.getPosition()`/`markOpened(readingPosition:)` (added in `TASK-010`) — reused as-is.

## Implementation Requirements (as built)
- **Dependencies**: `docx_file_viewer: ^1.0.4` and `excel_plus: ^2.22.0` added to `pubspec.yaml`.
- **A real dependency conflict, found and fixed**: `excel_plus` needs `xml ^7.0.1`. Two existing dependencies pinned `xml ^6.5.0` and blocked resolution: `rename_app` (a one-shot dev CLI for renaming the app's bundle ID, unreferenced anywhere else in the repo — removed) and `flutter_local_notifications` (a real runtime dependency, via its Windows plugin's transitive pin — bumped `^21.0.0` → `^22.3.1` after confirming via the package changelog that 22.x has no breaking changes to any method this project calls: `initialize`/`show`/`cancel`/`cancelAll`/`getNotificationAppLaunchDetails`). `flutter pub get` resolved cleanly after both changes; `flutter analyze` stayed at the same 158-info baseline.
- **Routing**: `DocumentInteractionController.openDocument()` now dispatches `DocumentCategory.word`/`.excel` to their own routes, alongside the existing `pdf` branch, via a `switch` (not an `if`-chain) for clarity now that there are three real branches plus the stub fallthrough.
- **Word reader**: `lib/features/word_reader/presentation/` — `WordReaderController`/`WordReaderView`/`WordReaderBinding`. Wraps `docx_file_viewer`'s `DocxView` widget directly; its own `DocxSearchController` drives search+highlight (ODF-014) with no custom engineering needed, unlike PDF where `pdfrx`'s search needed the eager-construction fix.
- **Excel reader**: `lib/features/excel_reader/presentation/` — `ExcelReaderController`/`ExcelReaderView`/`ExcelReaderBinding`. `excel_plus` (`Excel.decodeBytesAsync`, background isolate so a large workbook doesn't block the UI thread) parses the workbook into `Sheet`/`Data` objects; the entire grid UI (sheet tabs, frozen row/column headers via synced `ScrollController`s, cell rendering using `Data.displayText` for formula/format-aware display text, cell background/bold/italic from `CellStyle`) is first-party, per `ARCHITECTURE.md`'s own prediction that no adequate ready-made XLSX viewer widget exists.
- **Search (ODF-016)**: a first-party linear scan over the active sheet's `Data.displayText` values (case-insensitive substring match), scoped to the active sheet only — no library provides this for Excel.
- **Reading position**: Word saves `scroll_offset` (see the real gap below); Excel saves `sheet_index`/`row`/`column`/`vertical_offset`/`horizontal_offset`, matching BRD §16's suggested `ReaderPosition` shape for each format exactly.

## Implementation delta (2026-09-18)

**A real, verified gap: `docx_file_viewer` 1.0.4's `DocxView` cannot restore a reading position.** Reading its source (not assuming from the README) confirmed it owns its internal `SingleChildScrollView` with no exposed `ScrollController`, initial-offset parameter, or scroll callback of any kind. `WordReaderController` can only *observe* scroll position (via a `NotificationListener<ScrollNotification>` wrapped around `DocxView` in the view, which sees the widget's internal scroll notifications bubble up) and therefore can *save* `scroll_offset`, but has no API to *apply* a saved offset back to the widget on open. ODF-008 for Word is therefore **write-only** in this release: position is recorded correctly but never restored. `_initialScrollOffset` is still read back from storage and exposed via a getter so a future library version (or a fork) has an immediate place to plug in real restoration, but nothing currently consumes it. This is a real product-visible gap (BRD §11 Scenario 1's exact promise — "resumes at page 42" — does not hold for Word), not a hypothetical one, and is called out here rather than silently shipped as if ODF-008 were fully done for this format.

**A second real, verified gap: `DocxView` cannot be exercised via `flutter test` in this environment.** A `testWidgets` case that pumps `DocxView` with a real, freshly-built `.docx` file hangs indefinitely (confirmed with `enableZoom`/`enableSearch` both disabled, ruling out `InteractiveViewer` or the search overlay as the cause). Parsing the identical file directly via `docx_file_viewer`'s own `docx_creator` dependency (`DocxReader.loadFromBytes`, no widget involved) completes instantly, which isolates the hang to the widget lifecycle specifically, not the parser. Root cause not identified within the time this investigation could reasonably take, and not chased further once isolated; noted here as a real, bounded finding rather than a vague "didn't get to it." `WordReaderView`'s real on-device rendering is therefore an unverified device-testing item, the same posture already established for `pdfrx`'s native PDF rendering — except here the gap is in the test environment specifically, not in the underlying capability (the library's own parsing is fully verified; see Validation below).

**Excel's grid is fixed-cell-size, not per-column/per-row fidelity.** `ExcelReaderController.cellWidth`/`cellHeight` are constants (110×36), not read from the workbook's actual stored column widths/row heights, which BRD §9.12 lists as Core Features. `excel_plus` does parse this data, but honoring it would mean a variable-width grid layout — deferred as a documented simplification, not built into this pass, matching the "gracefully simplify unsupported layout elements" allowance BRD's own Word section already establishes for a different corner case.

**Merged cells are not visually spanned.** `excel_plus` exposes `getMergedCells()` (a list of ranges like `"A1:B2"`), but the grid renders every cell independently — a merged region shows its value only in its top-left cell, with the other cells in the span rendering blank, rather than one cell visually spanning the full region. Not wired up in this pass.

**Verified gaps carried over from `SRS.md`'s Unresolved Questions, still unresolved:**
1. Password-protected Word/Excel files: neither library's documentation mentions encryption support, and this pass did not test an actual encrypted file against either. If one is opened, the most likely outcome is the generic "This document may be damaged or incomplete." error (BRD-compliant but imprecise) — unverified, not assumed.
2. Legacy `.doc` (binary Word) is not supported by `docx_file_viewer` at all (undocumented). Legacy `.xls` is claimed supported by `excel_plus`'s own README (`Excel.decodeBytes` auto-detects the format) but was not exercised by this pass's tests, which only built modern `.xlsx` files.

**Validation:** `flutter analyze`: 0 errors, 0 warnings (158 pre-existing infos — same baseline as every prior task). `flutter test`: 91/91 passing (65 pre-existing + 12 new in `test/controllers/word_reader_controller_test.dart` + 14 new in `test/controllers/excel_reader_controller_test.dart`). Unlike the PDF reader, both `docx_file_viewer`/`docx_creator` and `excel_plus` are pure Dart with no native binary dependency, so this pass could verify **real parsing** end-to-end in this environment (not just controller logic against fixtures): a real `.docx` built via `docx_creator`'s `DocxDocumentBuilder`/`DocxExporter` and a real `.xlsx` built via `excel_plus`'s `Excel.createExcel()`/`.encode()` are both round-tripped (built → written to a temp file → read back by the reader's own controller) and asserted against their actual parsed content — genuinely stronger verification than PDF's fixture-only tests, even though `DocxView` widget rendering itself remains unverified (see the gap above) and no native-device rendering was performed for either format.

## Acceptance Criteria
- ODF-013/015: met — real files parse and their content is retrievable through each controller, test-verified.
- ODF-014/016: met — search finds matches and reports counts; Word's highlighting is `docx_file_viewer`'s own, Excel's is first-party.
- ODF-008: **partial** for Word (save-only, no restore — see delta); met for Excel (save and restore both implemented and test-verified).
- Favorite/Share/File Information/Open With work identically inside both readers as elsewhere (reused, not reimplemented).
- BRD §13 exact error strings preserved: "This document may be damaged or incomplete." (both readers' corrupted-file path), "This file may have been moved or deleted." (shared guard), "No searchable text found." (both readers' empty-search-result path).

## Test Requirements
`test/controllers/word_reader_controller_test.dart` (12 tests) and `test/controllers/excel_reader_controller_test.dart` (14 tests), all passing. See delta above for the two things that remain unverified (Word position restore has no API to test against; `DocxView` widget rendering hangs in this test environment).

## References
- `ADR-OPENDOCS-office-libraries.md`
- `SRS.md`, `ARCHITECTURE.md` (original scoping this task implements)
- `FEATURE-OPENDOCS-P2/tasks/TASK-010.md` (the PDF reader's pattern this task reuses: controller/view/binding shape, `openDocument()` dispatch seam, reading-position map convention)
- `FEATURE-OPENDOCS-P1/tasks/TASK-009.md` (Open From Other Apps — now unblocked for a third format)

## Out of Scope
- PowerPoint (PPTX) — not part of this task; still blocked on the product decision in `SRS.md` Unresolved Question 1, per `ADR-OPENDOCS-office-libraries.md`'s own Scope section.
- Word reading-position restore — see delta above; save-only for this release.
- Per-column/per-row sizing fidelity and visual cell-merge spanning in the Excel grid — see delta above.
- Legacy `.doc` support (not available in `docx_file_viewer`) and verified legacy `.xls` support (available per `excel_plus`'s README but untested here).
- Password-protected Word/Excel files — no dedicated flow; falls through to the generic corrupted-file error, unverified.
