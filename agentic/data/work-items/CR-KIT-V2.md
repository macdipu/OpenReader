# CR-KIT-V2: universal_document_viewer 0.2.0, one reader API and a professional package

## Status
**In progress.** The plan was written and work started on 2026-10-25 at the user's direction (below). Phase P1 of CR-READER-ROADMAP, plus the package-quality work the user asked for, plus app phase A2.

## Request (user, 2026-10-25)
"first plan, than start working if anything missing, also package need to clean and profesonal so people who code suitable for user and clear documentation how to use, and open to imrovemnt and contribute. also as this package as no user so fart so it is high timme we can refine it at its best"

## Decisions
- **Breaking changes allowed** (user: no users yet). 0.2.0 renames and reshapes freely, with no deprecation shims. The CHANGELOG has a migration table instead.
- **Names, chosen in this plan:** one pattern, `<Format>Controller` and `<Format>View`, for all five formats (table below). Library names are the format names.
- **Engines are headless plus a view.** Ready-made UI (toolbar, sheet tabs, slide arrows, dialogs) lives only in `DocumentViewer`, never in a format's view.

## Where the package stands (0.1.1 + `3af5710`)
- **Strong:** own engines, ZIP safety guard, isolate parsing, typed load errors, positions as JSON maps, thumbnails, 197 tests, pubspec metadata, a 300-line README, an example app.
- **Gaps** (measured 2026-10-25):
  1. 699 public members have no dartdoc. Most are in `word_model.dart` (135), `workbook.dart` (94) and `word_styles.dart` (61).
  2. `analysis_options.yaml` has no lint set.
  3. No CI, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY policy, or issue/PR templates.
  4. Two Word libraries (`docx.dart` and `word.dart`).
  5. Internals exported: `WordScope`, `WordBlockView`, `SheetGeometry`, `TextLineMetrics`, `pdf_layout.dart`, pagination types.
  6. Names follow five different patterns: `PdfDocumentController`, `WordDocumentController`, `SpreadsheetController` + `SheetGrid`, `SlideDeckController` + `SlideDeckView`, `TextDocumentController`.
  7. No shared controller API: zoom, position, go-to and search differ by format.
  8. Search counts lines (text), slides (slides), occurrences (Word, PDF).
  9. UI inside engines: `SlideNavigationBar`, the sheet zoom pill, `showGoToDialog`.
  10. No hook for an app's own strings or highlight colours.

## Target API (0.2.0)

| Format | Library | Controller | View | Was |
|---|---|---|---|---|
| PDF | `pdf.dart` | `PdfController` | `PdfView` | `PdfDocumentController` / `PdfDocumentView` |
| Word | `word.dart` | `WordController` | `WordView` | `WordDocumentController` / `WordDocumentView` (`docx.dart` + `word.dart`) |
| Excel, CSV | `spreadsheet.dart` | `SpreadsheetController` | `SpreadsheetView` | `SpreadsheetController` / `SheetGrid` (`sheets.dart`) |
| PowerPoint | `slides.dart` | `SlidesController` | `SlidesView` | `SlideDeckController` / `SlideDeckView` |
| Text | `plain_text.dart` | `PlainTextController` | `PlainTextView` | `TextDocumentController` / `TextDocumentView` (`text.dart`) |

**`universal_document_viewer.dart`** exports everything the shared contract, `DocumentViewer` and `DocumentThumbnails` need, and every format. The per-format libraries stay for apps that want one format. `testing.dart` keeps the in-memory document builders.

### The contract: `abstract class DocumentController extends ChangeNotifier`
- **Lifecycle:** `Future<void> loadFile(String path)`, `Future<void> loadBytes(Uint8List bytes)`, `DocumentStatus status` (`loading` / `ready` / `failed`), `DocumentLoadError? error`, `dispose()`.
- **Where the reader is:** `ValueListenable<DocumentLocation> location`, which holds `current` (1-based), `count` and `unit` (`page` / `slide` / `row` / `line` / `percent`). Plus `bool canGoTo` and `void goTo(int)`.
- **Saving the place:** `ReadingPosition get position`, plus `initialPosition` and `onPositionChanged` (unchanged, and `PositionKeys` stay as they are so saved positions keep working).
- **Zoom:** `double zoom`, `minZoom`, `maxZoom`, `canZoomIn`, `canZoomOut`, `zoomIn()`, `zoomOut()`, `setZoom(double)`. For text, zoom scales the font size.
- **Search:** `ValueListenable<DocumentSearchState> searchState` (`query`, `matchCount`, `currentMatch`, `isSearching`), plus `search(String)`, `nextMatch()`, `previousMatch()`, `clearSearch()`. Matches are **occurrences** in every format, and the current one is highlighted apart from the others.
- **Format extras stay on the subclass:** PDF view mode and password, Word layout and pages, sheet tabs, freeze and go-to-cell, slide previous/next, text wrap.

### Theming and strings
- `DocumentViewerTheme`, a `ThemeExtension`: match highlight, current-match highlight, go-to highlight, page background, page shadow.
- `DocumentViewerStrings`: the few built-in texts ("No matches", "Searching…", empty-sheet text, default error messages), replaceable by the app.

## Tasks, in order
**T1 · Repo hygiene and contributor setup** (non-breaking, so it goes first)
- `flutter_lints` plus `public_member_api_docs`, with `example/` analysed on its own.
- `CONTRIBUTING.md`: setup, the PDFium build hook, tests, regenerating test files, style, PRs.
- `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1) and `SECURITY.md` (the parsers read untrusted files, so report privately).
- `.github/`: issue templates (bug with a sample file, feature request), PR template, CI workflow (format, analyze, test, pana).
- `doc/architecture.md`: engines → controllers → views → `DocumentViewer`, and where a new format plugs in.

**T2 · Library layout and names:** the renames in the table above, one Word library, internals hidden.

**T3 · `DocumentController`:** implemented by all five controllers, with one shared contract test suite run against each.

**T4 · Occurrence search:** for plain text (line + offset) and slides (slide + block + offset), with a current-match highlight.

**T5 · No UI in engines:** drop `SlideNavigationBar`, the sheet zoom pill and `showGoToDialog`. `DocumentViewer` gains an optional default toolbar built only on the contract (position, zoom, search) and keeps sheet tabs and slide arrows.

**T6 · `DocumentViewerTheme` and `DocumentViewerStrings`.**

**T7 · Documentation**
- Dartdoc on every public member.
- README rewritten: a 3-line quick start, the contract, each format, theming, positions, errors, thumbnails, platform setup, contributing.
- CHANGELOG with the 0.1 → 0.2 migration table.
- Example app updated.
- pana at 160/160.

**T8 · OpenReader on 0.2.0 (app A2):** a shared `ReaderScaffold` over `DocumentController` replaces the six readers' copies of the app bar, search bar, error view and toolbar glue.

**T9 · Device QA on the phone; then the user pushes and publishes 0.2.0.**

## Done when
- The example app and OpenReader drive all five formats through `DocumentController` alone, plus each format's extras.
- `flutter analyze` is clean with the new lints, every public member is documented, and pana scores 160/160.
- Contract tests pass for every format, along with the existing tests.
- A newcomer can follow the README to show a document in 3 lines and CONTRIBUTING to run the tests, both in a clean checkout.

## Progress
- 2026-10-25: plan written.
- **T1 done** (package commits `465786a`, `0d738c2`, local, not pushed): flutter_lints, one formatting width (120), CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, issue/PR templates, CI, `doc/architecture.md`. pana **160/160** locally (the only deduction had been the unformatted generated bindings; `tool/pdfium/ffigen.dart` now formats its output).
- **T2 done** (`c8d6a9b`): renames per the table, one Word library, internals hidden, Word `BorderLine`/`CellBorders` → `WordBorderLine`/`WordCellBorders` (clashed with the spreadsheet model in the all-in-one export). CHANGELOG has the migration table. Package and example analyze clean; 197 tests pass.
- OpenReader still pins `3af5710`, so it is unaffected until T8.
- **T3–T6 done** (`202bf9b`):
  - **T3:** `DocumentController` (status, `location`/`goTo`, zoom, `search`/`searchState`), implemented by all five controllers, with a contract test suite run against each. Loading moved into the controllers (`loadFile`/`loadBytes`); PDF opens in its controller, from a path or from memory.
  - **T4:** occurrence-level search for plain text (`TextMatch`) and slides (`SlideMatch`), with a current-match highlight.
  - **T5:** `SlideNavigationBar`, the sheet zoom pill and `showGoToDialog` left the engine (the go-to dialog and its test moved to the example). `DocumentViewer` got a contract-only toolbar and `.bytes`.
  - **T6:** `DocumentViewerStrings` and its scope, and `DocumentViewerTheme`.
  - Fixed on the way: a damaged `.xlsx` opened as CSV; binary CSV wasn't refused.
  - Status: 233 tests pass, analyze is clean, pana 160/160.
- **T7 done** (`28c4943`): `public_member_api_docs` on, every public member documented (~580, written by three parallel agents and checked: comments only); README rewritten around 0.2; internal requirement IDs removed from package comments; `spreadsheet.dart` exports `DocumentFormat`; `PositionKeys.zoom` removed (unused). pana 160/160.
- **T8 in progress (app, uncommitted):** OpenReader moved to the 0.2 API (renames, `loadFile` everywhere, PDF opens in its controller with the password provider, `searchState` labels, occurrence matches, the go-to-cell dialog now app code). Analyze is at its baseline (106), 225 tests pass, and it's installed on the phone; on-screen check pending (phone locked).
  - Can't be committed until the engine commits are pushed, so the app can pin them; it builds against the local engine through `pubspec_overrides.yaml` until then.
  - Still to do in T8: the shared `ReaderScaffold` that replaces the six readers' duplicated app bar, search bar and error view.
