# CR-OPENREADER-UX Phase 1: implementation validation (2026-10-21)

Run `RUN-634FD576573D433995F3E16CB7BE4B57`, base revision `3a13d40`. Technical approval was recorded for user `macdipu` from an explicit in-session answer; UX-06 uses option A.

## Result
- `flutter test`: **146/146 pass**. Baseline was 140, plus 6 new tests.
- `flutter analyze --no-fatal-infos`: 0 errors, **2 warnings** (baseline 3), 146 infos (unchanged).
  - The remaining 2 warnings are the pre-existing unused `destructive`/`busy` parameters at `settings_view.dart:441-442`. That file was not touched.
  - Exit code is still 1 because warnings are fatal by default.
- `git diff --check`: pass.

## Acceptance evidence
| AC | Change | Test |
|---|---|---|
| UX1-AC1/AC2 | `BaseController.beginLoad()` goes to `refreshing` when content is already on screen. Home, Files, Favorites, Recents and Search use it. Their views render the full-screen `LoadingView` only for `isLoading`. Files shows a 2dp linear indicator while refreshing. | `document_views_test.dart`: "Home / All Files keeps content mounted while reloading", asserting status `refreshing`, no `LoadingView`, and the row still visible |
| UX1-AC3 | `FilesController.setSearchQuery` uses a 250 ms debounce `Timer`, cancelled in `onClose`. | "All Files debounces a typing burst into one query": 4 keystrokes give 1 `getDocuments` call |
| UX1-AC4 | `SearchDocumentsController.queryController`, cleared in `clear()` and disposed in `onClose`. | `ux_phase1_test.dart`: Search clear |
| UX1-AC5 | All 5 readers: `_ReaderAppBar(searching:)`. `preferredSize` is `kToolbarHeight + (searching ? 40 : 0)` and `bottom` is null when not searching. The `Scaffold` is wrapped in `Obx` so it re-reads `preferredSize`. | `ux_phase1_test.dart`: text reader app bar is 56 → 96 → 56 across a search toggle. Only the text reader is exercised (same code shape in all 5). |
| UX1-AC6 | `doc`/`xls` removed from `DocumentCategory._byExtension`, the incoming MIME map, and the Android VIEW/SEND intent filters (following the manifest's existing PowerPoint precedent). Existing rows are pruned on the next rescan by existing, tested behaviour. | `ux_phase1_test.dart`: legacy formats resolve to `unknown` and are not in `supportedExtensions`; `docx`/`xlsx` unchanged |
| UX1-AC7 | Word, Excel, Text and CSV show "No matches" for zero matches. The PDF keeps the BRD scanned-PDF text (deferred). | `ux_phase1_test.dart`: the label after a zero-match query |
| UX1-AC8 | Unused import removed from the in-scope `app_shell_controller.dart`. | Full suite and analyzer above |

## Scope note
`AndroidManifest.xml` and `incoming_document_resolver.dart` were not in the original affected-areas list. They were added because option A would otherwise leave OpenReader offering itself as an Open With handler for `.doc`/`.xls` and then refusing the file. The context was refreshed to include them.

## Not verified
- Nothing has been seen on a device or emulator. In particular, the PDF and Word viewers have not been checked for state preservation through the `Scaffold` rebuild on search toggle. Flutter keeps a widget's state when it is rebuilt with the same type and position, so their state should be preserved, but this is inferred, not observed.
- The `.doc`/`.xls` favorites/recents loss on rescan comes from the existing cascade-delete path; it was not separately re-tested against this change.
- The harness task durations for this run reflect `cli result` submission, not working time. The real working window was about 2026-10-21 15:21–16:05 UTC.
