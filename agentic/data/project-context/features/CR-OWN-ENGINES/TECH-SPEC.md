# TECH-SPEC: CR-OWN-ENGINES

Status: DRAFT. It needs the user's approval before implementation.

## Goal
Replace every third-party engine in `packages/open_reader_kit/lib/src/engines/` with open_reader_kit's own code, written from the file-format specifications. After that, move the kit to its own repo and publish it.

When this CR is done, `NOTICE.md` credits only:
- **PDFium:** Google's native PDF engine (BSD-3-Clause). The kit downloads it as a prebuilt binary and doesn't include its source.
- **The general-purpose packages from pub.dev the kit uses:** `archive`, `xml`, `ffi` and others. They stay ordinary dependencies, credited through their own licenses as usual.

## The clean-room rule (applies to every engine phase)
New engines are written from public specifications and from tests. Old engine code is never translated, renamed or paraphrased.

- **Specs:**
  - ECMA-376 / ISO 29500 (Office Open XML): SpreadsheetML for `.xlsx`, WordprocessingML for `.docx`.
  - RFC 4180 for CSV.
  - The PDFium public C headers (`fpdfview.h`, `fpdf_text.h`, `fpdf_doc.h`) for PDF.
- **While writing a new engine,** the implementer doesn't open the old engine's source files for that format.
- **Behaviour is pinned down by tests:** the app's existing tests, new fixture tests, and side-by-side checks against the old engine on real files.
- **Old engine removal:** the old engine stays until the new one passes parity. Then it's deleted, along with its `licenses/` file and its `NOTICE.md` row.

## What the kit actually needs (measured 2026-10-24)

| Engine today | Lines | What the kit and app use from it |
|---|---|---|
| `excel_plus` + `csv_plus` | 35.8k | Reading `.xlsx` and `.csv`:<br>• workbook sheet order and visibility<br>• rows of cells: string, int, double, bool, date, and formula with cached result<br>• `NumFormat`, cell style<br>• frozen rows and columns, max columns |
| `docx_creator` + `docx_file_viewer` | 48.3k | **The view:** `DocxView` in continuous page mode, with search.<br>**Tests only:** `DocxDocumentBuilder` + `DocxExporter`. Much of `docx_creator` exists to *write* `.docx` files, which the kit never does. |
| `pdfrx` + `pdfrx_engine` + `pdfium_dart` + `pdfium_flutter` | 35.7k | **The viewer:** `PdfViewer` with continuous or horizontal layout, a custom page layout, zoom, and page-change callbacks.<br>**Search:** `PdfTextSearcher` and page text.<br>**Documents:** open with a password, `PdfPageView`/`PdfImage` for thumbnails.<br>**Build:** the PDFium build hook and the darwin xcframework. |

## Phases (each its own commit; the app keeps working after each one)

### E1. Spreadsheet engine: CSV + XLSX (replaces `csv_plus`, `excel_plus`)
- **CSV:** `lib/src/engines/sheets/csv_reader.dart`, following RFC 4180:
  - quoted fields, `""` escapes, and line breaks inside quotes
  - CRLF, LF and CR line endings
  - a UTF-8 BOM
- **A small sheet model of our own,** shaped like the reader's needs: `Workbook` → `Worksheet` → cells with typed values, the style the grid shows, merged ranges, frozen panes and sheet visibility.
- **XLSX** (`xlsx_reader.dart`), after `ZipSafetyGuard`:
  - **Workbook:** `workbook.xml` (sheets, `state="hidden"|"veryHidden"`) and the relationships file.
  - **Text:** `sharedStrings.xml`, including rich-text runs.
  - **`styles.xml`:**
    - number formats, built-in and custom
    - fonts (bold, italic, colour)
    - fills
    - alignment and wrap
  - **Each sheet:** `sheetN.xml`:
    - cell types `s`/`n`/`b`/`str`/`inlineStr`/`e`
    - a formula's cached `<v>` value
    - frozen panes from `<pane>`
    - `<mergeCells>`
    - date serials through date formats
- **Off the UI thread:** parsing runs in `Isolate.run`. Our own model is plain data that can be sent between isolates, which removes today's "CSV on the UI isolate" limitation.
- **What else changes:** `SpreadsheetController`, `SheetGrid` and `CellText` move to the new model, and so does the app's `SheetReaderController`. `excel.dart` then exports our model instead of the engine.
- **Parity check:** the existing sheet tests, new fixtures (hidden sheets, merges, dates, formulas, rich text, frozen panes, a 6440-row file), and the same real files compared on the emulator, old engine against new.

### E2. Word engine (replaces `docx_creator`, `docx_file_viewer`)
- **Parser** (`lib/src/engines/word/`), reading WordprocessingML:
  - **Text:** paragraphs and runs (bold, italic, underline, strike, colour, size, highlight), styles from `styles.xml` with inheritance, and alignment, indents and spacing.
  - **Lists:** numbered and bulleted lists from `numbering.xml`.
  - **Tables:** including merged cells, shading and borders.
  - **Other content:** inline images through the relationships file, hyperlinks, page breaks, headers and footers. Text boxes show their text only.
- **Renderer:** Flutter widgets in one continuous scroll, lazily built with a `ListView`. It keeps today's contract: the `PrimaryScrollController` scroll position plus search with highlighted matches.
- **Tests:** a small `.docx` builder of our own replaces `DocxDocumentBuilder`/`DocxExporter`, in the same style as `pptx_test_builder`.
- **Fidelity baseline:** at least what OpenReader shows today. That includes the page-break fix from BUG-OPENREADER-WORD-PAGEBREAK.
- **Parity check:** the existing Word tests, new fixtures, and emulator comparisons on real documents.

### E3. PDF engine (replaces `pdfrx`, `pdfrx_engine`, `pdfium_dart`, `pdfium_flutter`)
- **Bindings:** our own FFI bindings, generated with `ffigen` from the PDFium headers and limited to the functions used:
  - setup and opening: init, load (from file or memory, with a password), last error
  - pages: page count, page size, render to a bitmap
  - text: text page, character boxes, find
  - outline (optional)
- **The PDFium binary:** our own build hook and darwin podspec, downloading prebuilt PDFium from `bblanchon/pdfium-binaries` (Android, iOS, macOS, Windows, Linux). The hash of each pinned binary is checked.
- **Engine API:**
  - `PdfDocument` with open, password errors, pages and close
  - page rendering to `ui.Image` in a background isolate
  - page text and search hits
- **Viewer widget:**
  - continuous vertical layout and horizontal layout
  - pinch and double-tap zoom, with tiles re-rendered at the zoom level
  - page tracking, jump to page, fit-width
  - search highlights, thumbnails, and a password callback
  - keeping the UI smooth on large PDFs
- **Parity check:** the existing PDF tests, plus emulator and macOS comparisons on these PDFs:
  - text, scanned and encrypted PDFs
  - a large one (500+ pages)
  - mixed page sizes
- **Web:** see open question Q1.

### E4. Clean-up
- Delete `lib/src/engines/` code that's no longer used, the `licenses/` files of replaced engines, and their rows in `NOTICE.md`.
- No upstream names are left anywhere. The search `grep -ri "pdfrx\|excel_plus\|docx_creator\|docx_file_viewer\|csv_plus\|pdfium_dart\|pdfium_flutter"` returns nothing.
- The analyzer is clean for the kit, removing today's 35 inherited warnings.

### E5. Split and publishing prep (the publish itself waits for the user's release approval)
- **New repo:** `chowdhuryelab/open_reader_kit`, starting fresh. It needs the user's `gh auth login` and repo-creation rights in the org.
- **pub.dev files:**
  - `LICENSE` (the user's choice, open question Q3) and `CHANGELOG.md`
  - a standalone `example/` app built on `DocumentViewer.file`
  - pubspec `homepage`/`repository`/`topics`, with `publish_to: none` removed
- **Release checks:** `dart pub publish --dry-run` is clean, and the kit's own tests run on CI.
- **The app:** `packages/open_reader_kit` is removed from OpenDocs. The app moves to a git dependency, then to the hosted package after publishing.

## Order and size (rough; measured in working sessions, not days)
- **E1, spreadsheets:** 2–3 sessions. Lowest risk; it proves the clean-room flow.
- **E2, Word:** 4–6 sessions. Rendering fidelity is the main work.
- **E3, PDF:** 6–10 sessions. Highest risk: native binaries, rendering performance and zoom.
- **E4 + E5:** 1–2 sessions.

## Risks
- **Fidelity regressions:** a new engine renders some real files worse than the old one. Mitigation: parity checks per phase, and the old engine stays until the new one passes.
- **PDF performance and memory** with large documents and deep zoom. Mitigation: tile cache limits, background rendering, and testing with a 500+ page PDF.
- **Native packaging** on 5 platforms. Mitigation: the hook and podspec pin exact binary versions with hashes. The APK and macOS builds are verified in every phase.
- **Time:** this is a large effort before 0.1.0 can ship. Publishing is blocked until E3 is done.

## Open questions (they need the user's answers; not assumed here)
- **Q1. Web support:** the current PDF web path runs pdfrx's wasm worker. Should 0.1.0 support web, which needs our own PDFium wasm build, or drop web for now? The kit would then support Android, iOS, macOS, Windows and Linux.
- **Q2. Word fidelity:** are headers and footers, footnotes, and a paged (print-layout) mode needed for 0.1.0? The baseline is a continuous view at today's level.
- **Q3. Kit license:** MIT (recommended), Apache-2.0 or BSD-3. It's needed by E5.
