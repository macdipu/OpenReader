# CR-OPENREADER-KIT: extract an `open_reader_kit` package (all document engines as editable source)

## Request (user, 2026-10-23)
- "why not build this app own package for app which can read all type of doc in future i will release package, and use this app as example to that package"
- "yes, open_reader_kit in packages/, go ahead pull all raw code from respetcted code so that i can fix add new feature as i want, first do that pland, double check and finaly is start"

## Decision (user, in-session 2026-10-23)
- **Package:** `open_reader_kit`, in this repo under `packages/`.
- **Engines:** every document engine the app uses becomes editable source inside the kit ("pull all raw code"), so the user can fix bugs and add features in them directly.
- **The app** becomes the kit's full example: it depends on the kit by path.
- **Release:** the user plans to publish the kit to pub.dev later. That step is not part of this CR.

## Plan
See `features/CR-OPENREADER-KIT/TECH-SPEC.md`.

## Run
`RUN-D7532679987249979346FE2D4A723869` (technical approval recorded; REVIEW and QA recorded 2026-10-24, waiting at QA → RELEASE for the user's release approval). Context scoped to the frozen TECH-SPEC only.

## Phase A: done (2026-10-23)
- **What was copied:** the 8 engines, verbatim, into `packages/open_reader_kit/third_party/` (see `VENDORED.md`).
- **Wiring:** the kit depends on them by path. The app depends on the kit and on the engines by path, and its overrides send the transitive engines to the copies too.
- **Checks:**
  - Analyze is clean for both the app and the kit.
  - All 235 tests pass.
  - The APK bundles `libpdfium.so`.
  - PDF, DOCX, XLSX and PPTX all open on the emulator.

## Amendment 1: done (2026-10-23)
- **User's request:** "why these tharparty why not bring open source code maintain" and "why not chnage there naming? as they are now and will maintain by me?"
- **Spec:** `features/CR-OPENREADER-KIT/TECH-SPEC-AMENDMENT-1.md`.
- **What changed:**
  - The engines are now open_reader_kit's own code under `lib/src/engines/{pdf,docx,excel}`, and `third_party/` is gone.
  - Entry points: `open_reader_kit/pdf.dart`, `docx.dart`, `docx_core.dart` and `excel.dart`.
  - The kit is now the PDFium FFI plugin itself: `hook/`, `darwin/`, `OpenReaderKitPlugin`.
  - `NOTICE.md` and `licenses/` keep the original copyrights.
  - The app depends on `open_reader_kit` only.
- **Checks:**
  - All 235 tests pass.
  - Analyze is clean for the app. The kit has 0 errors and 35 warnings that came with the upstream code.
  - The APK bundles PDFium for 3 ABIs.
  - The macOS build bundles `PDFium.framework`.
  - PDF, DOCX and XLSX open on the emulator.
- **Example app:** listed in the kit README with its Play Store link: https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader
- **Next:** Phase B, moving OpenReader's own readers into the kit.

## Phase B1: done (2026-10-23)
- **Moved into the kit:**
  - `ZipSafetyGuard` and `decodeTextBytes` → `open_reader_kit.dart`
  - `PptxParser` → `slides.dart`
  - `CellText`/`CellNumber` → `excel.dart`
  - the `.pptx` test builder → `testing.dart`
- **New in the kit:**
  - `DocumentFormat`: extension, path and MIME detection. The app's `DocumentCategory` and `IncomingDocumentResolver` now use it, so supported types are defined in one place.
  - `reader_contract.dart`:
    - `ReadingPosition` is a map, and its `PositionKeys` are the same keys the app already stores, so no data migration is needed.
    - `DocumentLoadError` lists the load failures as typed values.
- **Tests:** the app has 218, the kit has 21; that is the 17 that moved plus 4 new format tests. All pass, and analyze is clean.

## Phase B2–B5: done (2026-10-23)
The parallel agents hit the usage limit before saving any work, so B2–B5 were done in the main tree, one after another.

- **B3: slides and text.**
  - `SlideDeckController` + `SlideDeckView`/`SlideNavigationBar` (`slides.dart`).
  - `TextDocumentController` + `TextDocumentView` (`text.dart`). `TextLineMetrics` moved into the kit.
- **B2: spreadsheets.** `SpreadsheetController` (.xlsx with hidden sheets left out; CSV; sheets, search, zoom, scroll, position) + `SheetGrid`, which was `CellGrid` (`sheets.dart`). The app's Excel and CSV controllers now share `SheetReaderController`.
- **B4: Word and PDF.**
  - `WordDocumentController` + `WordDocumentView` (`docx.dart`).
  - `PdfDocumentController` + `PdfDocumentView` (`pdf.dart`), with `probePdfTextLayer`, `pdfSearchStatusLabel` and `pdfHorizontalLayout`.
  - The app keeps fullscreen, night mode, thumbnails and the password dialog.
- **B5:** `DocumentViewer.file(path, initialPosition, onPositionChanged)` picks the reader by type.
- **Kit conventions:** controllers are `ChangeNotifier`s with no GetX or storage, positions use `PositionKeys`, and errors are typed as `DocumentLoadError`.
- **App controllers:** these are now adapters. They keep the saved position (debounced, and saved again on close), favourites/share/open-with, BRD wording, and observable mirrors for their views.
- **Checks:**
  - App: 208 tests pass. Kit: 53 tests pass, including `DocumentViewer` widget tests.
  - Analyze is clean (only an older settings warning remains).
  - The APK builds.
  - On the emulator, PDF, DOCX, XLSX (6440), PPTX (reopened at 29/30) and TXT all open. Word also reopens at its saved scroll position.

## Commits
- `d03f301`: Phase A + Amendment 1.
- `d6f4369`: Phase B (B1–B5).

## Review: done (2026-10-24)
- **Rules checked:** the kit has no GetX, sqflite or app imports. Positions go through `initialPosition`/`onPositionChanged` with `PositionKeys`, and errors are typed as `DocumentLoadError`.
- **Fixed:**
  - `DocumentViewer`: a viewer closed mid-load could leak or reuse a disposed controller, and a changed `path` was ignored. It now adopts the controller only if it's still showing that path, and reopens when `path` changes.
  - `PdfDocumentController`: a failed text-layer check was an unhandled async error. It's now caught and checked again on the next empty search.
- **Optional, not done:** spreadsheet zoom doesn't rescale the scroll offset (behaviour carried over from the app).
- Evidence: `validation/review.json`.

## QA: done (2026-10-24)
- Kit: 55 tests pass. App: 208 tests pass.
- App analyze: 0 errors and 1 old warning (`settings_view`). The 109 info-level style lints were already there.
- The debug APK bundles PDFium for 3 ABIs.
- The emulator smoke test from Phase B was not repeated: the app doesn't use `DocumentViewer`.
- Evidence: `validation/qa.json`.

## Remaining
- **RELEASE:** needs the user's approval. Closes this CR; it does not publish to pub.dev.
- **Phase C (later):** `example/`, `CHANGELOG.md`, the Apache list of changes to `docx_file_viewer`, the 35 upstream analyzer warnings, `dart pub publish --dry-run`, and removing `publish_to: none`.
