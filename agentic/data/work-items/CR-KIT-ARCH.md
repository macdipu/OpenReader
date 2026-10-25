# CR-KIT-ARCH: architecture audit and refactor of universal_document_viewer

## Status
**Done (2026-10-25).** User request: "do this but first done this one". This is the architecture audit and refactor brief, done before the CR-KIT-V2 follow-ups (the go-to/zoom-before-view fixes and app phase A2).

## Baseline (package at `28c4943`, before any change)
- `dart format --set-exit-if-changed .` clean.
- `flutter analyze` clean, with flutter_lints and public_member_api_docs.
- `flutter test`: 233 passed. The example app: analyze clean, 1 test passed.
- pana 160/160.

## Dependency map (module → modules it imports; computed from `import` lines)
```
engines/sheets  -> engines/ooxml
engines/word    -> engines/ooxml
pdf             -> common, engines/pdfium
plain_text      -> common
slides          -> common, engines/ooxml
spreadsheet     -> common, engines/sheets, plain_text     <- cross-format edge
thumbnails      -> common, engines/*, pdf/word/spreadsheet/slides/plain_text views
viewer          -> common, pdf, plain_text, slides, spreadsheet, word
word            -> common, engines/word
```
No cycles. The only Flutter import under `engines/` is `foundation` in `engines/pdfium/pdf_engine.dart`, and only for `@visibleForTesting`. The engine also uses `dart:ui` to decode rendered pixels, which is a real rendering requirement.

## Findings

| # | Finding | Evidence | Action |
|---|---|---|---|
| 1 | Empty directories `src/pdf_reader/`, `src/sheets/`, `src/text/` | 0 files on disk and 0 tracked. They are leftovers on disk from the T2 renames (git doesn't track directories) | Remove |
| 2 | The spreadsheet module depends on the plain-text module | `spreadsheet_controller.dart` calls `PlainTextController.looksBinary` for CSV (added in T3) | Move the check to `common/text_decoding.dart` as `looksLikeBinary`; `PlainTextController.looksBinary` stays as a forwarding member |
| 3 | Parsers placed inconsistently | Word and spreadsheet parsers and models are in `engines/word`, `engines/sheets`; the PPTX parser and slide model are in `slides/` beside the controller and view | Move `pptx_parser.dart` to `engines/slides/` |
| 4 | Engine folder named differently from its module | `engines/sheets` vs `spreadsheet/` (and the public `spreadsheet.dart`) | Rename to `engines/spreadsheet` |
| 5 | Test-only builders sit in production engine folders | `engines/sheets/xlsx_test_builder.dart`, `engines/word/docx_test_builder.dart`, `slides/pptx_test_builder.dart`. They are public on purpose through `testing.dart` (documented in the README), so they stay in `lib/` | Move to `src/testing/`; `testing.dart` keeps its exports and names |
| 6 | The PDF engine imports Flutter for an annotation | `pdf_engine.dart` imports `package:flutter/foundation.dart show visibleForTesting` | Use `package:meta` |
| 7 | A forgotten `PdfiumDocument` leaks native memory | `close()` is guarded and every owner calls it (`PdfController`, the PDF thumbnail renderer, replaced documents), but there's no `Finalizer` | Add a `Finalizer` that closes a document collected without `close()`; `close()` detaches it |
| 8 | Public API leaks | Checked every entry point's exports: internals were removed in T2/T3; `PdfControllerView` and `probePdfTextLayer` are hidden | None; add a public-API test |
| 9 | No public API test | Nothing imports each entry point and checks its symbols | Add `test/public_api_test.dart` |
| 10 | Dependency rules not written down | `doc/architecture.md` describes layers but not the import rules | Document them; add a test that enforces them |

### Reviewed and left as is
- **`common/`:** seven small, cohesive files (contract, format, strings, theme, positions/errors, text decoding, ZIP guard). Nested sub-directories would add layering without a boundary.
- **`thumbnails/`:** shared orchestration (`document_thumbnails.dart`, `offscreen_render.dart`, `thumbnail_sources.dart`) plus one renderer per format behind `ThumbnailRenderer`. Each renderer depends on its format's engine/view and nothing duplicates them. Moving renderers into format modules would make every format depend on the offscreen-render infrastructure.
- **`engines/pdfium` vs `pdf/`:** native binding, worker isolate and `PdfiumDocument` in the engine; controller, layout, image cache and view in `pdf/`. No forwarding wrappers.
- **`engines/ooxml/opc_package.dart`:** generic ZIP/OPC parts and relationships, used by Word, spreadsheets and slides, with no format imports.
- **Capability model:** not added. Every format implements all of `DocumentController`, so there's nothing to advertise per format. The real gaps are behavioural (finding 12), not missing capabilities.

### Security and lifecycle (reviewed)
- **ZIP:** `ZipSafetyGuard` checks the central directory before any decompression (entry count, declared uncompressed total, path traversal). The ZIP reader enforces declared sizes while inflating. Office files over `maxFileBytes` aren't read. Unchanged.
- **XML:** `package:xml` resolves only the predefined and numeric entities and does not expand DTD-declared entities, so there's no entity-expansion ("billion laughs") path. No external entity fetching.
- **Size limits:** text and CSV 20 MB, Office 200 MB file / 500 MB declared uncompressed. PDF `loadFile` passes the path to PDFium, which reads lazily; PDF `loadBytes` takes caller-supplied bytes.
- **PDFium worker:** one long-lived isolate, started lazily and shared. A start failure or isolate death fails every pending and later call with `PdfEngineException` instead of hanging. Requests are prioritised and cancellable. The isolate isn't shut down while the app runs (by design: PDFium is initialised once per process).
- **Controllers:** `DocumentController` drops state updates after `dispose` (`isDisposed` guards `mark*`, `updateLocation`, `updateSearch`, `reportPosition`); loads that finish after dispose discard their results.

### Not in scope here (CR-KIT-V2 follow-ups)
- 11: shared reader screen in OpenReader (app A2).
- 12: `goTo` before a view exists is lost for plain text, spreadsheets and Word's continuous layout; PDF `setZoom` before its view exists is lost.

## Progress
- Audit done (this file).
- **Refactor done** (package `d812afe`, local): findings 1–10 implemented as listed. No public API change; `looksLikeBinary` is new. Final tree and rules are in the package's `doc/architecture.md`.
- **Checks after:** format clean; analyze clean; 243 tests (233 + public API 3 + import rules 6 + XML safety 1); example analyze + 1 test; pana 160/160; OpenReader analyze at its baseline (106) and 225 tests pass.
- **Not verifiable here:** the `Finalizer` path (GC timing isn't testable deterministically); PDFium on iOS, Windows and Linux (only macOS host tests and the Android device run).
- **Follow-ups done** (package `cf5d377`, `23c9caa`): finding 12 fixed. `goTo` and PDF zoom made before a view are kept and applied once it has laid the document out (`deferGoTo`/`applyPending`). New tests also found and fixed:
  - a `PdfView` built after its document opened span forever, which broke every PDF in `DocumentViewer`;
  - `WordView`/`PlainTextView` controller swaps kept stale state;
  - `SpreadsheetView` swaps didn't restore offsets.
  The README now has "Where the formats differ". 250 package tests pass; OpenReader analyze is at its baseline and its 225 tests pass.

