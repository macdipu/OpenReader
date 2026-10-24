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

## E2a + E2b Word engine: done (2026-10-24)
- **New code:** `lib/src/engines/word/`. Old-engine ideas came from E2-WORD-NOTES.md; the code itself is new.
  - `word_model.dart`: a plain, sendable model. Blocks are paragraphs, tables and section breaks. Inlines are text, tab, break, image, note reference and bookmark. Formatting is resolved, list markers are numbered, and there are sections with headers and footers, notes and images.
  - `word_styles.dart`:
    - the theme's fonts and colours (tint and shade)
    - run and paragraph property bags
    - styles following the §17.7 cascade: the `w:default` paragraph style, cycle-safe and memoised `basedOn` walks, and toggle properties XOR'd between paragraph and character styles
    - table styles with conditional formats
    - numbering: counters per abstract list, `w:start`, `startOverride`, `lvlText` templates, and Symbol-font bullets
  - `docx_reader.dart`: one block parser for the body, cells, headers, footers, notes and text boxes.
    - Runs keep every child in order, so a tab or break no longer drops text.
    - Fields: results are shown and instructions hidden; HYPERLINK fields become links.
    - Links: web links, and bookmarks within the document.
    - Images: inline, anchored and VML.
    - Tables: grid spans, vMerge row spans, borders and shading, `tblLook` in both forms.
    - Sections with page setup; headers and footers inherited across sections.
    - Footnotes and endnotes numbered by first reference. Tracked changes show as accepted; hidden text is left out; equations show as text.
  - `docx_test_builder.dart` (`buildDocx`).
- **View (`lib/src/word/`):**
  - `WordDocumentLayout` numbers paragraphs in reading order.
  - `WordSearchController` indexes the text once. Case folding keeps offsets valid, and each paragraph looks up its own highlights in O(1).
  - `WordDocumentView` is a lazy `ListView`.
    - Search jumps directly when the paragraph is built, otherwise to an estimate first.
    - The saved offset is restored over a few frames.
    - Note marks open a bottom sheet, and the notes are listed at the end.
    - Web links open only for http, https and mailto; bookmark links jump.
  - Widgets:
    - Paragraphs own and dispose their tap recognizers.
    - Text keeps the file's colours where they stay readable. Links use the document's hyperlink colour.
    - Tables use a custom grid layout (no `IntrinsicHeight`), so cells spanning rows take the full height and shared borders aren't doubled.
  - The controller parses in `Isolate.run`.
- **Removed:**
  - the old Word engine, `lib/src/engines/docx/` (about 48k lines)
  - `docx_core.dart`
  - the docx_file_viewer and docx_creator license files and NOTICE rows
- **Checks:**
  - Text parity with each document's own `w:t` text is exact on four files: the python-docx fixture, two real QA documents, and one written by the old engine's writer.
  - Tests: the kit has 96, adding the reader, styles, numbering, fields, notes and view widgets. The app has 208, including a real view scroll-restore test that replaced the old stand-in. All pass.
  - Analyze: the kit's inherited warnings went from 35 to 4, all in the PDF engine. The app shows only the old `settings_view` warning.
  - The APK builds.
  - **Emulator:**
    - `features.docx` shows the header, styles, the link, lists, the merged table, the image and the page-break divider.
    - `qa-word.docx` reopens at its saved position, and search jumps to an unbuilt paragraph and highlights it.
- **Remaining for E2:** E2c, the paged print layout from DECISIONS.md Q2: pages measured with `TextPainter`, real page breaks, and headers and footers on each page.
- **Engine code left in the kit:** about 39.8k lines, down from about 120k. Only the PDF engine (E3) is still upstream code.

