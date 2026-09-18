# Engineering Task

## Status
DONE (implemented, `flutter analyze`/`flutter test` verified) — 2026-09-18. Implemented directly against `SRS.md`/`ARCHITECTURE.md` in this session ("Start implementation"). No ADR was needed (see `ARCHITECTURE.md` Status) since this phase introduced no new dependency.

## Story
Text and CSV Readers (BRD §9.14–9.15, Phase 4)

## Objective
ODF-019 (TXT read), ODF-020 (CSV read as grid), ODF-008 (reading-position restore for TXT/CSV).

## Dependencies
- No new library. TXT uses Flutter's own text widgets; CSV reuses `excel_plus` (already a dependency since `FEATURE-OPENDOCS-P3`).
- `DocumentInteractionController`'s `openDocument()` dispatch seam, `RecentRepository.getPosition()`/`markOpened()` — reused as-is.
- The Excel reader's grid widget (`FEATURE-OPENDOCS-P3/TASK-011`) — extracted into a shared component this task depends on.

## Implementation Requirements (as built)
- **Shared grid extraction**: `ExcelReaderView`'s file-private `_Grid`/`_HeaderCell`/`_DataRow`/`_DataCell` moved to `lib/core/presentation/widgets/cell_grid/` as `CellGrid` (public widget) plus a `CellGridController` interface (`currentRows`, `columnCount`, `matches`, `currentMatchIndex`, both scroll controllers, initial offsets, `onScrolled()`) and a shared `CellMatch` model. `ExcelReaderController` now `implements CellGridController`; `ExcelReaderView` was reduced to a thin wrapper around `CellGrid`. Confirmed behavior-preserving: all 14 pre-existing Excel reader tests pass unmodified after the extraction.
- **Text reader**: `lib/features/text_reader/presentation/` — `TextReaderController`/`TextReaderView`/`TextReaderBinding`. Reads the file directly (`dart:io`), decodes via a new shared `decodeTextBytes()` utility (UTF-8 first, Latin-1 fallback), renders lines through a virtualized `ListView.builder` (only visible lines are built, bounding widget-tree memory even though the whole decoded string is held). Owns a real `ScrollController` directly (unlike the Word reader), so reading position works both ways — save **and** restore, with no equivalent gap.
- **Binary-file detection**: a heuristic scan of a byte sample (NUL byte, or >5% non-whitespace control bytes) catches BRD §9.14's "Binary file renamed as `.txt`" corner case, mapping it to the existing generic corrupted-file message instead of rendering garbage.
- **Size ceiling**: both new readers refuse a file over 20 MB (a first-pass, adjustable constant — not derived from any BRD-specified number, since none exists) with the existing "This document is too large to render safely on this device." message, rather than attempting to read/decode/parse an arbitrarily large file synchronously.
- **CSV reader**: `lib/features/csv_reader/presentation/` — `CsvReaderController`/`CsvReaderView`/`CsvReaderBinding`. Parses via `excel_plus`'s `Excel.fromCsv`, wrapped in `Isolate.run` (see delta below), and renders through the shared `CellGrid` — no sheet-tab bar, since CSV has one implicit sheet. Search and reading-position persistence mirror the Excel reader's shape exactly (`ARCHITECTURE.md`'s own prediction).
- **Routing**: `DocumentInteractionController.openDocument()` gained `text`/`csv` branches in its existing `switch`, following the established pattern (each reader owns its own `markOpened` calls).

## Implementation delta (2026-09-18)

**The `ARCHITECTURE.md` Risk 2 finding was real and has been fixed, not just documented.** `excel_plus`'s `Excel.fromCsv` has no isolate-friendly entry point (confirmed by reading its source before implementation started). `CsvReaderController._load()` wraps the parse call in `Isolate.run(() => xls.Excel.fromCsv(csvText))` itself, verified safe by `Excel.decodeBytesAsync`'s own implementation (`Isolate.run`, handing the result back via `Isolate.exit` rather than a deep copy) — the same mechanism, applied by this codebase instead of assumed to exist inside the library. Test-verified: parsing completes correctly across the isolate boundary (real spin-up latency required test helpers to poll for load completion rather than use a single fixed delay, unlike every other controller test in this codebase, which resolve near-instantly against fixture repositories).

**Word's ODF-008 gap does not recur here.** `FEATURE-OPENDOCS-P3/TASK-011` documented that `docx_file_viewer`'s `DocxView` exposes no scroll-control API, making Word's reading position save-only. The Text reader owns its content and scrolling directly (no opaque third-party widget), so both save and restore are implemented and test-verified for TXT — confirming `SRS.md`'s prediction that this gap was specific to Word's chosen library, not systemic to first-party-rendered formats.

**CSV header-row and delimiter detection defaults were applied exactly as `SRS.md` proposed, not elaborated on.** No explicit header-row toggle or delimiter auto-detection was built; `excel_plus`'s CSV import defaults (comma delimiter) are used as-is. Both remain the two SRS Unresolved Questions' proposed defaults, not upgraded to something smarter, since no sign-off to do more was given.

**Large-file handling is a size ceiling plus virtualized rendering, not disk-backed windowing.** `ARCHITECTURE.md` flagged this as unverified against a real large-file corpus; this pass implements the simpler of its two proposed approaches (a hard ceiling with BRD's existing "too large" message) for both readers, plus `ListView.builder`'s ordinary lazy-build virtualization for TXT specifically. True streaming/windowed reading of a file larger than the ceiling was not built — BRD's "1M+ rows"/"very large text file" corner cases are handled by refusing to open rather than by successfully rendering them progressively.

**Jump-to-match scrolling in the Text reader is an approximation**, not pixel-exact: `_jumpToLine` estimates a target offset using a fixed average line height, since wrapped long lines make an exact per-line pixel offset impractical without per-line layout measurement (documented in the controller's own doc comment). Functionally lands in the right neighborhood; not verified to be exact on a real device with genuinely long wrapped lines.

**Encoding detection matches its stated narrow scope exactly**: UTF-8-first with Latin-1 fallback, test-verified with a real non-UTF-8 byte sequence. No BOM sniffing, no statistical charset detection. A file in an encoding neither of those two decoders "wins" on (Latin-1 always succeeds, technically, even on wrong input) would render as mojibake rather than being caught as an error — this is an inherent limit of the fallback design (Latin-1 has no failure mode to detect), not a missed case, and is called out here so it isn't mistaken for one.

**Validation:** `flutter analyze`: 0 errors, 0 warnings (158 pre-existing infos — same baseline as every prior task). `flutter test`: 118/118 passing (91 pre-existing + 16 new in `test/controllers/text_reader_controller_test.dart` + 11 new in `test/controllers/csv_reader_controller_test.dart`). Both new readers' tests build and parse **real** files (a real `.txt` with genuine non-UTF-8 bytes and a genuinely binary-looking payload; a real `.csv` with quoted commas and a multi-line quoted value, exercising BRD's own stated hard corner cases directly) rather than relying on fixtures alone — the same higher-verification-quality pattern `FEATURE-OPENDOCS-P3/TASK-011` established, since neither format needs a native binary dependency.

## Acceptance Criteria
- ODF-019/020: met — real files parse/render and their content is retrievable through each controller, test-verified including BRD's own named hard corner cases (quoted commas, multi-line quoted CSV values, non-UTF-8 text, binary-renamed-.txt).
- ODF-008: met for both TXT (save **and** restore) and CSV (save and restore, matching the Excel reader's shape).
- Favorite/Share/File Information/Open With work identically inside both readers as elsewhere (reused, not reimplemented).
- BRD §13 exact error strings preserved: "This document may be damaged or incomplete." (binary-file/unreadable-file path, both readers), "This document is too large to render safely on this device." (size ceiling, both readers), "This file may have been moved or deleted." (shared guard), "No searchable text found." (both readers' empty-search-result path).

## Test Requirements
`test/controllers/text_reader_controller_test.dart` (16 tests) and `test/controllers/csv_reader_controller_test.dart` (11 tests), all passing. `test/controllers/document_interaction_controller_test.dart`'s dispatch test extended to cover all five implemented reader categories (PDF/Word/Excel/Text/CSV) in one pass.

## References
- `ARCHITECTURE.md`, `SRS.md` (original scoping this task implements, including the Risk 2 finding this task resolved rather than just carried forward)
- `FEATURE-OPENDOCS-P3/tasks/TASK-011.md` (the pattern this task reuses, and the Word ODF-008 gap this task's Text reader does not repeat)
- `lib/core/presentation/widgets/cell_grid/` (the shared grid extracted in this task)
- `FEATURE-OPENDOCS-P1/tasks/TASK-009.md` (Open From Other Apps — now unblocked for every category this app plans a reader for except PowerPoint)

## Out of Scope
- PowerPoint (PPTX) — not part of this task; still blocked on the product decision in `FEATURE-OPENDOCS-P3/SRS.md` Unresolved Question 1.
- CSV header-row-detection toggle and delimiter auto-detection beyond `excel_plus`'s own comma-delimited default — see delta above.
- True streaming/windowed reading for files past the size ceiling — see delta above.
- Full charset auto-detection beyond UTF-8/Latin-1 — see delta above.
- TASK-009 (Open From Other Apps) itself — not implemented; only its "no reader exists" blocker is further cleared.
