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
- **Engine code left in the kit:** about 39.8k lines, down from about 120k. Only the PDF engine (E3) is still upstream code.

## E2c Word print layout: done (2026-10-24)
- **`WordParagraphStyler` + `ParagraphGeometry`** (`word_paragraph_styler.dart`): one builder of a paragraph's spans, inline-widget sizes, offset map and geometry. Both the paragraph widget and the page measurer use it, so what is measured is what is drawn.
  - The root text style is explicit (`inherit: false`). Before, the app's Material letter spacing and font leaked into the widget but not into `TextPainter`, so a split piece measured 4 lines and drew 5.
- **`WordMeasurer` + `WordPaginator`** (`word_pagination.dart`):
  - Pages per section use that section's page size and margins.
  - Explicit page breaks (an empty piece keeps the paragraph mark on the next page, as in Word), `pageBreakBefore` and section breaks all start new pages.
  - Paragraphs split between lines (`TextPainter` line metrics mapped back to text offsets). Tables split between rows and repeat header rows.
  - Never clips: a block that can't split goes on a page of its own, and the page grows.
  - Notes go on pages after the body.
- **Live page numbers:** `PAGE` and `NUMPAGES` fields are now `WordPageField`s. The paged view shows real numbers; the continuous view shows Word's saved result.
- **Paged view:** pages on white paper (dark text, whatever the app theme), drawn at real size and scaled to fit the width. Each page shows its section's header and footer (the first-page ones when `titlePg` is set) in the margins.
  - Search jumps work through `pageOfParagraph`.
  - Switching layout keeps the top paragraph in view; a header falls back to the next body paragraph.
- **Saved position:** `view_mode` is saved alongside `scroll_offset`, and `WordDocumentController.restore` reapplies both.
- **App:** the menu toggles "Print layout" / "Continuous layout", and the app saves the kit's whole position map.
- **Thin borders:** under 1 px they're drawn as hairlines (one device pixel at any scale). Before, 0.3 px lines on scaled-down pages vanished at random. Each cell draws top and left, plus bottom and right on the table's outer edge.
- **Checks:**
  - **Tests:** the kit has 100, adding pagination: no text lost or repeated across splits, breaks and sections, header-row repeat, footer page numbers, and rendered page bodies no taller than measured. The app has 209, adding a test that restores print layout with its offset and toggles it from the menu. All pass.
  - **Emulator:**
    - `features.docx`: print layout shows pages with headers and footers, the page break, the landscape section and full table borders, and it reopens in print layout.
    - `qa-word.docx`: switching from continuous at paragraph 7 lands on paragraph 6 in print layout, and pages fill to the bottom margin.

## E3a PDF native layer and engine: done (2026-10-24)
- **Design notes:** `E3-PDF-NOTES.md`, from the survey of the old pdfrx engine (idea level).
- **Hook (`hook/build.dart`):**
  - bblanchon/pdfium-binaries **`chromium/8086`** (PDFium 157.0.8086, 2026-10-05), with SHA-256 pinned for all 13 archives. Covers Android (4 ABIs), iOS device and simulator, macOS, Linux and Windows.
  - A cached library is reused only with a matching hash stamp. Downloads have timeouts and are written atomically.
  - iOS is skipped until E3b removes the old `darwin/` xcframework.
- **Our own bindings:** `tool/pdfium/ffigen.dart` (ffigen 23, programmatic API) generates `lib/src/engines/pdfium/pdfium_bindings.g.dart`.
  - 36 functions in 384 lines, against 14k lines before.
  - `@Native` functions bound to the `package:open_reader_kit/libpdfium` asset; no library loading by hand.
  - Built from headers kept in `tool/pdfium/include` along with PDFium's licence.
- **Worker (`pdfium_worker.dart`):** one isolate owns PDFium.
  - Priority queue (visible, prefetch, background), back to the event loop between tasks, and cancelling of queued requests.
  - The last error is read in the same call as the open, so password detection is right on Windows too.
  - LRU of page and text-page handles.
  - Rendering goes straight to RGBA (`FPDF_REVERSE_BYTE_ORDER`) and comes back via `TransferableTypedData`.
  - Displayed sizes come from the crop box and `/Rotate`. `FPDF_GetPageWidthF/HeightF` turned out to give the unrotated size; tests caught it.
  - Text boxes are mapped to the displayed page (crop-box offset plus rotation).
  - Search runs in the worker: line breaks are joined so a wrapped phrase matches, case folding keeps offsets valid, and rects are merged per line along the reading direction, so rotated pages work too.
  - Links: annotation URIs and GoTo targets, plus web addresses written as text.
- **API (`pdf_engine.dart`):** `PdfiumDocument.openFile/openBytes` with password, typed `PdfOpenException`, `pageSizes`, cancellable `render` (region or tile), `renderThumbnail` (the whole page, unlike the old service's crop), `text`, `search`, `links`, `close`. `PdfRenderedImage.toImage` uses `ImageDescriptor.raw`.
- **Checks:**
  - 9 engine tests run against the real PDFium on the macOS host, using reportlab fixtures:
    - sizes with rotation, a rotated page rendering turned, region renders
    - text boxes, search (case, wrapped phrase, rotated page, page without text)
    - links of both kinds
    - password retry, damaged and missing files, cancelling
  - The kit has 109 tests and the app 209, all passing.
  - The APK bundles the new PDFium for 3 ABIs, and the current viewer opens `qa-text.pdf` on the emulator with it.
- **Next: E3b.** The viewer widget and controller switch, the thumbnail strip and service, removing pdfrx, the wasm assets, `darwin/`, the link hook and `ffiPlugin`, enabling iOS in the hook, NOTICE, and device checks. Open question L1 (PDF link taps) defaults to supporting them.

## E3b part 1: new PDF viewer switched in (2026-10-24)
- **Kit (`lib/src/pdf_reader/`), rewritten on the own engine:**
  - `PdfLayout` (pure): continuous and horizontal layouts, binary-searched visible pages, and a sticky current-page rule.
  - `PdfImageCache`: base images bucketed to 256 px steps (at most 2000 px), plus 512 px tiles at 2x, 4x and 8x for zoomed views. It works within a byte budget with LRU eviction, cancels renders that are no longer wanted, and is requested from the view's transform listener, never from paint.
  - `PdfDocumentView`: Flutter's own `InteractiveViewer.builder`, building only pages near the viewport.
    - Double-tap zoom, wheel scrolling (Ctrl/Cmd + wheel zooms).
    - Search highlights, link taps (web links only for http, https and mailto; in-document links jump), and `onTap` for the app.
  - `PdfPageThumbnail` widget.
  - `PdfDocumentController` owns `open` with the password retry loop. It keeps every name the app used, and replaces `PdfTextSearcher` with a streaming `PdfSearchController`.
- **App:**
  - The PDF reader's controller and view use `isReady`/`searchController`, and the thumbnail strip uses `PdfPageThumbnail`.
  - `PdfThumbnailService` renders the whole first page with `renderThumbnail`; the old engine cropped the top-left corner.
- **Checks:**
  - Tests: kit 109, app 209, all passing.
  - The APK builds.
  - On the emulator, `features.pdf` renders with "Page 1 of 4", and searching "needle" gives "1 of 2 result(s)" with a highlight.
- **The old pdfrx engine is still in the tree,** unused by the app. It's removed in the next session (see the plan below).

## E3b part 2: device checks and fixes (2026-10-24, commit 58d2796)
Emulator results:
- **Search** across pages, including the rotated page 3: "2 of 2", with the highlight exactly on the word.
- **Zoom:** at 2.5x (double-tap) and 6x the text stays sharp, because the tiles render; a stretched base image would blur.
- **Thumbnail strip:** all pages render, including the rotated one; the current page is outlined, and a tap jumps.
- **Horizontal layout:** the toggle works, and reopening restores both the layout and the page.
- **Links:** "Go to the end" jumps to page 3, and the web link opens Chrome.
- **Password:** a wrong password shows "Incorrect password."; the right one opens the file.
- **Night mode** inverts the page. In fullscreen, a tap brings the controls back.
- **Home thumbnails:** the fix was to add a render version to the cache key. Before it, the old engine's cropped PNGs (top-left corner only) were still being reused from disk.
- **600-page PDF:** fast flinging keeps pages rendered; search found a line on page 550 and jumped there.
Fixes:
- **Faster open:** `FPDF_GetPageSizeByIndexF` reads sizes with `/Rotate` applied and without loading any page; each page's geometry is read lazily. Opening 600 pages on the host went from about 1.2 s to about 350 ms. On the host, searching all 600 pages takes about 0.7 s, and rendering a page about 9 ms.
- **Horizontal snapping** at page width: a flick moves one page, and a slow drag settles on the nearest.

## Parallel agents (user: "deploy multi agent for faster work", 2026-10-24)
- **Agent A:** remove the old PDF engine, `darwin/`, the wasm assets and `link.dart`; enable iOS in the hook; NOTICE with PDFium and its bundled third-party licences; prune dependencies (this covers E4 dependency pruning); macOS and iOS builds.
- **Agent B:** thumbnails for every type: a kit `lib/src/thumbnails/` API and the app's `DocumentThumbnailService`.
- Each works in its own worktree; the results are merged after review.

## NEXT SESSION PLAN (saved 2026-10-24, at the user's request)
Run: `RUN-60D2C2882A324C15AAD0FBB0A9DC42DF` (IMPLEMENTATION). Do these in order:

1. **E3b: finish the PDF switch.**
   - **Device checks on the emulator, with fixes:**
     - next/previous match moving to page 3 (rotated page highlight)
     - zoom in/out, fit width, and tile sharpness at 2x, 4x and 8x
     - horizontal layout toggle and position restore (page + `view_mode`)
     - the password dialog flow (`test/fixtures/pdf/encrypted.pdf`, password `secret`)
     - the thumbnail strip, link taps (web link and "Go to the end" → page 3), night-mode colour filter, fullscreen tap
     - home-screen PDF thumbnails
     - a large PDF (500+ pages) for memory and scrolling smoothness
   - **Remove the old engine:**
     - `lib/src/engines/pdf/` (pdfrx, pdfrx_engine, pdfium_dart, pdfium_flutter)
     - `assets/pdfium/` (web wasm; web was dropped in DECISIONS Q1)
     - `darwin/` (CocoaPods/SwiftPM xcframework), `hook/link.dart`
     - pubspec `ffiPlugin`/`sharedDarwinSource` and the assets entry
   - **iOS:** enable it in `hook/build.dart` by deleting the iOS skip.
   - **macOS:** verify the macOS app build after `darwin/` goes, because the hook now supplies the dylib.
   - **NOTICE.md:**
     - drop the pdfrx-family rows and their `licenses/` files
     - credit PDFium (BSD-3) and the third-party licences shipped in the archive (`licenses/*.txt` in pdfium-binaries: freetype, icu, libjpeg-turbo, lcms, libpng, zlib, abseil, harfbuzz, openjpeg, and others)
     - list `lib/src/engines/pdfium/` as the kit's own code
2. **NEW (user's request, 2026-10-24): thumbnails for every type.**
   - **What:** today only PDFs get a home-list thumbnail. Add first-page previews for Word (.docx), Excel (.xlsx), CSV, PowerPoint (.pptx) and text.
   - **Plan:** a kit API such as `DocumentThumbnails.render(path, width) -> PNG bytes`, per format:
     - **PDF:** `renderThumbnail`
     - **Word:** page 1 from `WordPaginator`, drawn offscreen to an image
     - **PowerPoint:** slide 1
     - **Sheets:** the top-left grid of the first visible sheet
     - **Text/CSV:** the first lines
   - **App:** generalise `PdfThumbnailService` into a `DocumentThumbnailService` (same disk cache keyed by path and modified time), and have `DocumentListTile` show it for all types.
   - Tests per format.
3. **E4: clean-up.**
   - Prune kit dependencies the removed engines needed: check `equatable`, `html`, `markdown`, `pointycastle`, `uuid`, `yaml`, `image`, `web`, `rxdart`, `http`, `synchronized`, `collection`, `meta`.
   - Analyzer clean for the kit.
   - `grep -ri "pdfrx\|excel_plus\|docx_creator\|docx_file_viewer\|csv_plus\|pdfium_dart\|pdfium_flutter"` must return nothing.
   - Refresh the kit README.
4. **E5: repo split and pub.dev prep** (TECH-SPEC). It needs the user's licence choice (DECISIONS Q3: MIT recommended, Apache-2.0 or BSD-3), `gh auth login`, and creating `chowdhuryelab/open_reader_kit` (fresh start).
   - `LICENSE`, `CHANGELOG`, a standalone `example/`, `dart pub publish --dry-run`.
   - Switch the app to a git dependency.
   - The publish itself needs release approval.
5. **Then:** REVIEW, QA and RELEASE for the run. The release approval is the user's.

**Still open:** BUG-OPENREADER-COLDSTART-INTENT (a crash when a file is opened from another app on a cold start; it predates this work).

