# CR-READER-SELECT-OCR: select, copy, highlight and bookmark in every reader, plus OCR

Status: **APPROVED PLAN (2026-11-22), implementation starts with docs and the Phase 0 spike.** Technical gate not yet requested; TECH-SPEC is written after the spike.
Owner repos: **Kit (`universal_document_viewer`) and OpenReader**, split per the table below (AGENTS.md section 1).
Traceability: Kit roadmap `agentic/data/work-items/CR-READER-ROADMAP.md` (text selection and copy P2, outline API A4, bookmarks need a product decision). Requirement IDs `SO-xx` anchor tasks, tests and QA.
Source plan: `/Users/dipu/.claude/accounts/dipu/plans/snug-tinkering-walrus.md` (revision 2, approved 2026-11-22).

## Current Behavior
- PDF pages are bitmaps; there is no way to select or copy text even from a born-digital PDF. Word and plain text are real text but have no selection. Markdown, Slides (per slide) and Excel/CSV can already select and copy.
- PDFium text and per-character boxes already exist in the Kit (`PdfiumDocument.text(page)`) but only search uses them.
- No OCR, no outline/TOC, no bookmarks, no persistent highlights, no image viewer.

## Requested Change (user, 2026-11-22)
Add copy for documents; add OCR when part of a PDF is an image. PDFs that are not images (a doc exported to PDF) must support select, copy, highlight and bookmarks by default. Audit the other document types and set a standard for desktop and mobile. OCR on Android, macOS, Windows and Linux. Full selection everywhere. OCR language is detected automatically: by the engine if it can, otherwise by the app's own detection.

## Ownership (decided; test = generic, reusable, no OpenReader logic)
| ID | Requirement | Owner |
|---|---|---|
| SO-01 | PDF text layer: hit-testing, selection model and painting, word/line granularity, cross-page | Kit |
| SO-02 | `SelectionArea` on Word, plain text, slides (one area across slides) | Kit |
| SO-03 | Optional controller API `selectedText`, `copySelection()`, `clearSelection()`, `selectAll()` (default no-op) | Kit |
| SO-04 | Selection menu/toolbar (Copy, Select all) with `extraSelectionActions` hook | Kit |
| SO-05 | Clipboard write and feedback strings (`DocumentViewerStrings`) | Kit |
| SO-06 | "Copy all text" in the readers' ⋮ menu only. Copy and Select all come from the system selection toolbar, right-click menu and keyboard (user decision 2026-11-22) | OpenReader |
| SO-07 | `OutlineEntry` data for PDF bookmarks, Word headings, slide titles | Kit |
| SO-08 | Outline panel (desktop side panel, mobile sheet) | OpenReader |
| SO-09 | Paint supplied highlight rects; expose selection as a stable anchor | Kit |
| SO-10 | User highlights, bookmarks, notes: storage, restore | OpenReader |
| SO-11 | OCR contract `TextRecognizer`, `OcrInput`, `OcrResult` (+ `supportsAutoDetect`, `detectedLanguage`, `confidence`) | Kit |
| SO-12 | OCR plumbing in `PdfView`/`PdfController`: scanned-page detection, page render, recognise, cache, invisible OCR text layer | Kit |
| SO-13 | OCR trigger UI: action/banner, progress, cancel, errors | OpenReader |
| SO-14 | Engines: ML Kit (Android), Apple Vision (macOS), Windows.Media.Ocr (Windows), Tesseract (Linux) | OpenReader |
| SO-15 | Privacy-policy text and the merged-manifest audit. OCR is always on wherever an engine exists: no setting, no switch (user decision 2026-11-22). The language resolver was dropped with Q3 (only model-supported languages) | OpenReader |
| SO-16 | Excel/CSV and Markdown: no behaviour change, regression tests only | none |

## Standard UX
Input model follows the last pointer kind (mouse vs touch), not only the OS.
- **Desktop:** I-beam over text; drag select; double-click word; triple-click line/paragraph; Shift+click extends; edge auto-scroll; Ctrl/Cmd+C, Ctrl/Cmd+A, Esc; right-click menu (Copy, Select all, app actions, selects the word under the cursor when nothing is selected); wheel and Ctrl/Cmd+wheel keep scroll and zoom.
- **Mobile:** long-press (light haptic) selects a word; two handles with magnifier, 48dp targets, edge auto-scroll; floating toolbar (Copy, Select all, app actions) hides while scrolling; tap clears; pinch, pan, double-tap-zoom unchanged.
- Shared: strings from `DocumentViewerStrings`, colours from `DocumentViewerTheme` (night mode included), foldable/tablet breakpoints as existing, screen-reader semantics, "Copied" feedback, OCR text never logged.

## Out of Scope
- Image viewer / `DocumentFormat.image` (not needed); camera capture (adds a permission).
- Writing annotations into the PDF file.
- Extra language work: only model-supported languages (no Bengali/Tesseract `ben` effort).
- iOS and web OCR (not shipped).

## Phases
0 spike and ADR (custom selection model vs `SelectionContainer`/`Selectable`); 1 real-text formats; 2 PDF text layer; 3 OCR contract and PDF plumbing; 4 engines, resolver, UI; 5 outline, highlights, bookmarks (gated on a product decision).
Kit release is a minor version (0.3.0), additive, no new dependency. Publishing needs the owner's explicit approval each time.

## Decisions on the open questions (user, 2026-11-22)
- Q1: bookmarks and highlights are user-created, stored in an app database (sidecar, never written into the file). Phase 5 is no longer gated on this.
- Q2: Linux OCR with Tesseract ships in the first OCR release.
- Q3: no per-language work. OCR supports only the languages the engines' own models support; the resolver just picks among installed/supported models, and Bengali is not a goal.
- Q4: image viewer is not needed (dropped, not only deferred).
- OCR has no "Enable OCR" setting: it is always on where the platform has an engine (user, 2026-11-22).
