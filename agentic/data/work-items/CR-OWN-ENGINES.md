# CR-OWN-ENGINES: open_reader_kit's own document engines before its first pub.dev release

## Request (user, 2026-10-24)
- "now open_reader_kit … make separate repo, from there i want to publish this to pub dev as well"
- "as i dont want to keep all other name in my kit, can you break there code base and re write in my engine so that i can claim them to mine?"
- Answer given in-session: Claude won't rewrite or rename upstream code to remove its credits, because a derived copy stays the upstream authors' work. The legitimate route is new engines written from the format specs. The user chose **"Own engines before publishing"**.

## Decisions so far (user, in-session 2026-10-24)
- **Repo:** `chowdhuryelab/open_reader_kit`, starting fresh with no history from OpenDocs.
- **App dependency after the split:** a git dependency on the new repo until the first pub.dev release, then `open_reader_kit: ^<version>` from pub.dev.
- **When to publish:** only once the kit's engines are its own code.
- **Kit license:** not decided yet. The user asked for an explanation; it was explained and is still open. It's needed before publishing, not before implementation.

## Classification
Change request. CR_TASKS level (engine by engine), NO_REPLAN. There is no sprint planning.

## Plan
`project-context/features/CR-OWN-ENGINES/TECH-SPEC.md`

## Run
`RUN-60D2C2882A324C15AAD0FBB0A9DC42DF`

## E1 Spreadsheet engine: done (2026-10-24)
- **New code (`lib/src/engines/sheets/`),** written from ECMA-376 SpreadsheetML and RFC 4180. The old engine's source wasn't opened.
  - `workbook.dart`: the model (`Workbook`, `Worksheet`, `SheetCell`, `CellValue` types, `CellStyle`). It's plain data, so it can be sent between isolates.
  - `number_format.dart`: Excel number formats:
    - General, placeholders, grouping and scaling, percent, scientific, fractions
    - sections and conditions, currency tags
    - dates and times, elapsed time, the 1904 date system, the 1900-02-29 quirk
  - `xlsx_reader.dart`: streams the sheet XML.
    - Reads shared and inline strings, formulas with their saved results, styles (bold, italic, solid fill with theme tint and indexed colours) and frozen panes.
    - Sheet visibility is read; hidden sheets are left out.
  - `csv_reader.dart`: RFC 4180.
    - Handles quotes, line breaks inside fields, CR/LF/CRLF line endings and a BOM.
    - Detects whether the delimiter is `,`, `;`, tab or `|`.
    - Numbers keep their written form, so `007` stays `007`.
  - `xlsx_test_builder.dart` (`buildXlsx`) replaces the old engine's writer in tests.
- **Wiring:** `SpreadsheetController`, `SheetGrid` and the app's `SheetReaderController` use the new model. Both `.xlsx` and CSV now parse off the UI isolate; CSV used to block it.
- **Removed:**
  - the old engine: `lib/src/engines/excel/` (about 35.8k lines)
  - `excel.dart`, `cell_text.dart`
  - the `licenses/` files and `NOTICE.md` rows for excel_plus and csv_plus
- **Parity, comparing the old engine's public API with the new reader on the openpyxl fixtures:**
  - 51,623 cells show identical text.
  - 1 differs, and the new reader is correct there: the old engine printed the raw `[Red]` currency format code instead of `($42.00)`.
  - Fills: the old engine gave plain RGB fills alpha 00, so they were invisible on screen. The new reader draws them.
- **Checks:**
  - **Tests:** the kit has 71, including number formats, the XLSX and CSV readers and the controller. The app has 208. All pass.
  - **Analyze:** the new code is clean. The kit's 35 remaining warnings are in the PDF and Word engines. The app shows only the old `settings_view` warning.
  - **Speed:** a 6440-row × 8-column `.xlsx` parses in about 140 ms on the host.
  - **Emulator** (opened through Browse):
    - `features.xlsx` shows dates, fills, bold and italic, and leaves out the hidden sheets.
    - `large.xlsx` (6440 rows) scrolls smoothly.
    - `qa-data.csv` reopens at its saved row.
- **Found during the checks:** BUG-OPENREADER-COLDSTART-INTENT, a crash when a file is opened from another app while OpenReader isn't running. It predates E1: PDF crashes the same way.
- Committed with the E1 follow-up (see the E1 commit).

## E1 follow-up: ideas from the old engine, written better (2026-10-24)
- **The user's direction:** "do look old code took the idea and write them in better way scalabe way". Recorded as an amendment in DECISIONS.md.
- **Shared package layer:** `lib/src/engines/ooxml/opc_package.dart` (OPC, ECMA-376 Part 2).
  - Finds parts case-insensitively, resolves relationships (internal and external) and finds the main part.
  - `XlsxReader` and `PptxParser` now use it instead of their own copies. E2's Word reader will use it too.
- **Layout and formatting in the model:**
  - **Layout:** column widths, row heights, hidden rows and columns, merged ranges, hyperlinks (web links, and links to places in the workbook).
  - **Cell style:** text colour, underline, strikethrough, font size, horizontal and vertical alignment, wrapping.
- **`SheetGeometry`:** pure Dart, tested. It turns the layout into positions on screen (prefix sums and binary search) and handles hidden rows and columns and frozen panes. It's the single source used by both the controller and the grid.
- **Controller:**
  - Search matches are indexed by row, so the grid looks up a cell's highlight in O(1). Before, each row scanned every match.
  - Search skips hidden cells.
  - Positions and jump-to-cell come from the geometry.
  - New `openInternalLink`.
- **`SheetGrid` rebuilt on `TableView`** from `two_dimensional_scrollables` 0.5.5, the Flutter team's package:
  - Only on-screen cells are built. The old grid built every column of every row.
  - The file's widths and heights, hidden rows and columns, frozen panes pinned, and merged cells. A merge that would cross a frozen edge is left unmerged, because `TableView` can't merge across pinned panes.
  - The file's text formatting and alignment, with contrast kept readable on fills and in dark mode.
  - **Links:** the cell detail sheet has "Open link". Web links open only for `http`, `https` and `mailto`; links inside the workbook jump to the target cell.
  - Excel's default bottom alignment is drawn centred, because rows here are taller than Excel's for touch.
- **Checks:**
  - **Tests:** the kit has 79, adding geometry, grid widgets (hidden rows and columns, widths, merges, links) and reader layout and formatting. The app has 208, unchanged. All pass.
  - **Analyze:** the new code is clean.
  - **APK:** builds.
  - **Emulator:** `features.xlsx` shows the file's widths, the tall row 8, hidden row 9, the frozen row and column, fills, coloured underlined text and the link.
- **Next:** E2, the Word engine. Its scope includes footnotes and endnotes and a paged layout (see DECISIONS.md).

