# CR-READER-ROADMAP: phased improvements for universal_document_viewer (package) and OpenReader (app)

## Status
**Backlog (proposal).** Not started, no run, nothing approved. Each phase becomes its own CR, with a technical plan approved before any code.

## Request (user, 2026-10-25)
"do details planing package improvement which are app imptove ment list phased", after asking for a rating of the package.

## Where things stand (2026-10-25)
- **Package** at `3af5710` (version 0.1.1; the 0.1.0 release is on pub.dev). Own engines for PDF (PDFium bindings), Word, Excel/CSV, PowerPoint and text. 197 tests.
- **App** at `8897576`. Every reader has the bottom toolbar (position · zoom · tools · full screen), page previews for PDF/Word/PowerPoint, and consistent ⋮ menus and Find. 225 tests.
- **Settings slimmed (user, 2026-10-25, uncommitted).** Settings now has Appearance, Cache and About only.
  - "Default PDF Reader Mode" moved to the PDF toolbar's layout button. The mode last picked there becomes the default for PDFs that don't remember their own.
  - "Clear Recent History" removed; reading history is cleared from Library > History.
- **Direction this sets:** reading options belong in the reader's toolbar, not in Settings. A3's reading themes and text options follow it.
- **Known weaknesses** (from the review in this session):
  1. No common API across formats: zoom, position, go-to and search each differ.
  2. Engine ships some UI chrome (the sheet zoom pill, `SlideNavigationBar`, `showGoToDialog`).
  3. Search counts different things: lines (text), slides (PowerPoint), occurrences (Word, PDF).
  4. Pinch-zoom only in PDF.
  5. Hard-coded English strings and highlight colours in the engine.
  6. PowerPoint is a reading view, not the slide layout.
  7. No legacy `.doc/.xls/.ppt` (see CR-LEGACY-OFFICE).
- **Open bugs:** BUG-OPENREADER-COLDSTART-INTENT; BUG-OPENREADER-WORD-PAGEBREAK.

Sizes: S ≈ a day, M ≈ a few days, L ≈ a week or more.
⚖ = needs a product decision from the user before it's planned (never assumed).

---

## Package track (universal_document_viewer)

### P1 · One reader API (0.2.0, breaking) - M/L
The basis for most app work (A2, A3).
- **Common controller contract**, implemented by `PdfDocumentController`, `WordDocumentController`, `SlideDeckController`, `SpreadsheetController` and `TextDocumentController`:
  - **position:** `current`, `total` and `unit` (page / slide / row / line / percent), plus `goTo(int)`. One `ValueListenable` for the toolbar.
  - **zoom:** `zoom`, `minZoom`, `maxZoom`, `canZoomIn/Out`, `zoomIn/Out` and `setZoom`. Text maps it to font size.
  - **search:** `query`, `matchCount`, `currentMatch`, `next`, `previous` and `clear`, as one `ValueListenable<SearchState>`.
  - **status:** `isLoaded`, `error` and `position` (the saved JSON map, as today).
- **Search counts occurrences in every format.** Text and slides currently count lines and slides. Every format gets a distinct current-match highlight, and slides jump to the match.
- **One `searchStatusLabel`** replaces `pdfSearchStatusLabel`.
- **No UI chrome in the engine:**
  - deprecate `SlideNavigationBar`;
  - in 0.2, `SheetGrid.showZoomControls` defaults to off;
  - `showGoToDialog` becomes `SpreadsheetController.goTo` plus a dialog that lives in the example app.
- **Strings and colours:** a `DocumentViewerStrings` delegate ("No matches", "Searching…", the empty-sheet text) and a `DocumentViewerTheme` ThemeExtension (match / current-match / go-to highlights, page background, night inversion).
- **Done when:** the example app drives all five formats through one toolbar written against the contract, the old APIs are deprecated with a migration note in the CHANGELOG, and the tests cover the contract for each format.

### P2 · Interaction (0.3.0) - M
- **Pinch-zoom** in Word (pages scale, continuous text reflows), slides, text (pinch → font size) and sheets. Double-tap zoom behaves the same everywhere, and all of it routes through P1's `setZoom`.
- **Outline / table of contents API:** PDF bookmarks, Word headings (style-based) and slide titles, each as `List<OutlineEntry>(title, level, target)`. Needed by A4.
- **Text selection and copy** that works the same in every format (Word, text, slides, sheet cells, PDF text layer).
- **Word continuous layout gets page numbers:** paginate in the background so it shows "Page ~x of y" as well as print layout.
- **One `PageThumbnail` widget** for PDF, Word and slides (today it's `PdfPageThumbnail` and `WordPageThumbnail`, with slides done in the app).

### P3 · Fidelity (0.4.0) - L
- **PowerPoint slide layout:** shapes placed by `xfrm` on a 16:9 / 4:3 canvas, slide/layout/master backgrounds, theme colours and fonts, pictures where they sit. The current reading view stays as an option, which keeps reflow for phones.
- **Word:** floating images and text boxes, columns, and different first-page / even-page headers. Picks up BUG-OPENREADER-WORD-PAGEBREAK.
- **Sheets:** ⚖ charts (render or a placeholder?), and showing hidden sheets on request.

### P4 · Legacy formats (0.5.0+) - L
Unchanged from **CR-LEGACY-OFFICE**: a CFB reader and safety guard first, then `.xls`, `.doc` and `.ppt`. P1 makes each new format plug straight into the common contract.

### P5 · Quality, running alongside every phase - S each
- Golden screenshot tests per format.
- Parser fuzzing (ZIP, XML, CFB).
- Large-file benchmarks with memory caps.
- Full dartdoc coverage, plus one example app page per feature.
- Keep the pub.dev score at its maximum.

---

## App track (OpenReader)

### A1 · Finish and stabilise what we have (now) - S/M
- ✅ **Settings → toolbar** (2026-10-25): PDF reading mode in the toolbar, Settings' Clear Recent History removed (see "Where things stand").
- Fix **BUG-OPENREADER-COLDSTART-INTENT**, plus the related finding from 2026-10-25: a `file://` VIEW intent while the app is running throws `Null check operator` in GetX `PageRedirect.page` (from `didPushRouteInformation`).
- **Find:** Shift+Enter goes to the previous match.
- **Spreadsheet row counter:** count the first *fully* visible row (it's one short today).
- **Word continuous:** a document that fits on one screen shows 100%, not 0%.
- ⚖ **Menu labels:** capitalise only the first word ("Open with", "File information") or every word.
- ✅ **Checkable menu items:** settled. Night mode left PDF's ⋮ menu for the toolbar, so no checkable items remain beside plain ones.
- **Housekeeping:** push the engine (`3af5710`), delete the local `pubspec_overrides.yaml`, run `flutter pub get`.

### A2 · One reader screen (needs P1) - M
- One shared reader screen (`ReaderScaffold`) driven by P1's contract: app bar, search bar, bottom toolbar, previews, full screen and error view. Each reader supplies only its body and its own tools.
- Removes the six copies each of `_ReaderAppBar`, `_SearchStatusBar` and `_ReaderErrorView`, plus the per-reader escape and full-screen glue.
- **Done when:** every reader keeps today's behaviour, all tests pass, and the reader code is much smaller.

### A3 · Reading comfort (P1 for theming) - M
- ✅ **Night mode in every reader** (user, 2026-10-25): a 🌙 toolbar button just before full screen, one choice shared by all readers and remembered (kept under PDF's old key). White-paper content (PDF, Word print layout, thumbnails) is inverted with hues kept; theme-following content (text, Word continuous, slides, sheets) switches to the app's dark theme.
- **Reading themes for all readers** (light / sepia / dark): the rest of this item, chosen from each reader's toolbar, not from Settings.
  - ⚖ Is the last theme picked the default for every reader, the way PDF's reading mode now works?
- **Bars auto-hide** while scrolling down and come back on scrolling up or a tap.
- **Remember zoom/layout per document,** alongside the saved position. The last choice becomes the default for new documents of that type (the rule the PDF mode now follows). Word's print/continuous layout already works this way per document.
- **Keep the screen awake** while reading. ⚖ Always on, or a setting?
- **Text reader:** ⚖ a font choice (sans / serif / mono), and an automatic monospace for code and log files.

### A4 · Find and navigate (P2 for the outline) - M
- An **outline panel** (table of contents) from P2's outline API, opened from the toolbar.
- **Find options:** match case and whole word. Recent searches per document.
- **Go-to that knows its context:** PDF page labels (e.g. "iv"), and Excel sheet!cell.
- ⚖ **Bookmarks and notes** per document. This is a new feature, so it needs a product decision first: storage, sync, export.

### A5 · Library and opening - S/M
- **Open-with reliability:** cold start (A1), `content://` URIs, large files.
- Turn on legacy file types as each P4 format ships (file filters, intent filters, Browse).
- ⚖ **Recent files show the thumbnail of the page you left off on.** The package can already render it.

### A6 · Accessibility and languages - M
- Semantics labels for every toolbar control (some icon-only buttons rely on tooltips today).
- TalkBack/VoiceOver pass on every reader.
- Check right-to-left layout.
- Route the app's own strings through localisation (the app already has a locale controller), and give the engine its strings through P1's `DocumentViewerStrings`.

### A7 · QA and release, alongside every phase - S each
- Widget tests per reader: toolbar, full screen, previews.
- Golden screenshots.
- A device matrix: small phone, large phone, tablet, desktop.
- Store release checklist.

---

## Order and dependencies
```
Now:      A1  ─────────────────────────────►
Package:  P1 (0.2.0) ──► P2 (0.3.0) ──► P3 (0.4.0) ──► P4 (CR-LEGACY-OFFICE)
App:            └► A2 ──► A3     └► A4         A5 follows P4
Ongoing:  P5, A6, A7
```
Recommended next: **A1** (small; fixes known bugs), then **P1 + A2** together, since the API and its first user are designed together.

## Open questions
- Whether 0.2.0 may break the API (P1). The proposal is yes, with deprecations and a migration note, because the package has only just been published.
- The ⚖ items above.
- Settings is down to Appearance, Cache and About. ⚖ Should it stay a full screen, or become a short sheet from Home's ⋮ menu?
- Whether the app's version and store release follow each package release or ship on their own schedule.

## Next step
The user picks a phase. Then: intake (a canonical CR), then a technical plan for that phase, then the user's approval, then code.
