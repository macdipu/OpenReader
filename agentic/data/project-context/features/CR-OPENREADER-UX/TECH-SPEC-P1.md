# CR-OPENREADER-UX Phase 1: technical spec

Status: PROPOSED (awaiting technical approval). Source revision `3a13d40`. Run `RUN-634FD576573D433995F3E16CB7BE4B57`.

## Baseline (2026-10-21)
- `flutter test`: 140/140 pass.
- `flutter analyze --no-fatal-infos`: 0 errors and 3 pre-existing warnings; exit 1 because warnings are fatal by default. The warnings are an unused import at `app_shell_controller.dart:10` and the unused `destructive`/`busy` parameters at `settings_view.dart:441-442`, so they all sit outside Phase 1 logic. `app_shell_controller.dart` is in scope, so its unused import gets removed. The settings warnings are left alone.

## Design

### UX-01/02/03: keep content mounted during reloads
- Add `BaseController.beginLoad()`. If the current status is `success`, `empty` or `refreshing`, it sets `refreshing`, so content is already on screen. Otherwise (initial or error) it sets `loading`. The decision comes from the current status alone; no new state is tracked.
- In `load()`, Home, Files, Favorites, Recents and Search call `beginLoad()` instead of assigning `StateStatus.loading`.
- Those five views switch the full-screen `LoadingView` condition from `status.isBusy` to `status.isLoading`.
- Files shows a 2dp `LinearProgressIndicator` under the sort chip while `refreshing`. Home already has `_ScanProgressBanner` for scans, so a plain tab-switch reload stays silent.
- Readers and File Information keep `isBusy`. They load once, so no flicker comes from them.
- Files `setSearchQuery` gets a 250 ms debounce `Timer`, matching `SearchDocumentsController`, cancelled in `onClose`.

### UX-04: Search clear
`SearchDocumentsController` owns a `TextEditingController queryController`, passed to the app-bar `TextField`. `clear()` also calls `queryController.clear()`, and the controller is disposed in `onClose`.

### UX-05: reader app-bar height
Each of the five `_ReaderAppBar`s takes a `searching` flag. `preferredSize` is `kToolbarHeight + (searching ? 40 : 0)` and `bottom` is null when not searching. Each reader's `Scaffold` is wrapped in `Obx`, which reads `controller.isSearching.value` and passes it down, because `Scaffold` reads `preferredSize` only when it is itself built. The body widgets keep their own `Obx`; rebuilding a widget with the same type and position keeps its state, so `PdfViewer` is not recreated.

### UX-26: zero-match label
- Word, Excel, Text and CSV readers show "No matches" when the query is not empty and there are no matches.
- The PDF reader keeps BRD §9.x's prescribed "No searchable text found." text for now. The BRD defines that message for scanned PDFs without a text layer (line 1087), and telling that case apart from an ordinary zero-match search needs a text-layer probe. That is an open question, not done in Phase 1.

### UX-06: legacy `.doc`/`.xls`
The BRD requires these "if rendering engine supports acceptable fidelity" (lines 125/127). Neither engine does: `docx_file_viewer` and `excel_plus` are ZIP/OOXML only. The BRD also says "Ignore unsupported files from document lists" (line 175) and "Unsupported files do not pollute normal lists" (line 1609). There are two options; the user chooses at technical approval:
- **A (BRD-aligned, recommended): stop indexing them.** Remove `doc` and `xls` from `DocumentCategory._byExtension`. The scanner ignores them, the next rescan prunes existing rows (existing behaviour, covered by tests), and the file picker stops offering them. The cost: these files become invisible in OpenReader, which can no longer share them or hand them to Open With.
- **B: keep indexing them, with an unsupported-format flow.** `DocumentInteractionController.openDocument` detects extension `doc`/`xls` and shows a dialog: "This older .doc/.xls format can't be displayed in OpenReader" with "Open with another app" and Cancel. This deviates from BRD line 175 for these two extensions.

## Impact
- **Affected modules:** core presentation (`base_controller`), features `home`, `files`, `favorites`, `recents`, `search` and the 5 readers, `app/shell`, plus either `core/domain/models/document_category` (A) or `document_interaction_controller` (B).
- **Not affected:** database schema, repositories, scanner traversal logic, platform channels and dependencies.
- **Risk: low to medium.** The status semantics change touches every list screen. Mitigation: widget tests for "content stays during refresh" on Home and Files, the existing loading/empty/error/retry tests, a debounce test with a fake clock, and a Search clear widget test.
- **Option A data effect:** existing favorite and recent rows for `.doc`/`.xls` cascade-delete on the next rescan (foreign keys). This is a user-visible loss of those favorites.

## Test plan (maps to UX1-AC1…AC8)
- New widget tests in `test/widgets/document_views_test.dart`:
  - AC1/AC2: refresh keeps content mounted with no `LoadingView`.
  - AC3: rapid `enterText` produces one query after 250 ms.
- New `test/widgets/search_view_test.dart`: AC4.
- Reader app-bar test: pump a reader view and assert the `AppBar` height with search off and on (AC5). If a reader can't be pumped without platform plugins, AC5 falls back to a unit test of `preferredSize`.
- AC6: option A gets a `DocumentCategory.fromExtension('doc') == unknown` plus scanner-exclusion test; option B gets a `DocumentInteractionController` test asserting the dialog and that no reader route is pushed.
- AC7: a label test via the Text reader controller and view.
- AC8: full `flutter test` and `flutter analyze --no-fatal-infos`.

## Out of scope
UX-07 PowerPoint (product decision pending, `FEATURE-OPENREADER-P3` UQ1), the PDF text-layer probe, and all P1/P2 items.
