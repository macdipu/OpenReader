# CR-EXCEL-READER-AUDIT: audit-first requirements for the read-only Excel reader

## Run
`RUN-6780549E98B74690B709F92E03DE3083` (change_request, planning NO_REPLAN), registered 2026-11-11 while `RUN-60D2C2882A324C15AAD0FBB0A9DC42DF` (CR-OWN-ENGINES) waits at REVIEW. The user chose to finish CR-OWN-ENGINES' IMPLEMENTATION result first, then start this CR.

## Request (user, 2026-11-11)
A pasted requirements document, "Excel Reader: Audit-First Requirements". In short:
- **Audit before implementation.** Do not rebuild, redesign or replace the existing reader. Trace the whole flow (import, parse, workbook model, grid, formatting, selection, search/filter/sort, export/print), check desktop, tablet and mobile, run the app and tests, and record each requirement as Implemented / Partial / Missing / Broken / Unsupported with a P0/P1/P2 priority.
- **Deliver an audit report first**: feature inventory, source files per feature, device behaviour, bug reproductions, performance and accessibility notes, risks, recommended order.
- **Implement only approved gaps**, using the current architecture. No second selection engine, no new spreadsheet library without a documented limitation and approval.
- **Scope is read-only.** No editing, no recalculation engine, no AI, accounts or cloud sync.
- Sections 4 to 15 of the request list the capabilities to verify: file types (.xlsx .xls .xlsm .csv .tsv), grid rendering and formatting, selection on desktop and touch, selection statistics, copy, search and go-to, sort and filter (non-destructive), responsive layouts, zoom/freeze panes, export and print, performance, accessibility, security.
- Sections 16 to 19: testing requirements, implementation rules, the execution workflow and the definition of done.

The full text is in the session that created this work item; it is not copied here. The numbered sections above are the traceability anchors.

## Known starting facts (from the repo, before the audit)
- Spreadsheet engine is the package `universal_document_viewer` (own repo `github.com/macdipu/universal_document_viewer`, local checkout `../universal_document_viewer`), used by the app by git ref `main`. Changes to the grid or parser are made there, then the app's pin is bumped.
- Legacy `.xls` is a known backlog item, `CR-LEGACY-OFFICE`, "coming soon": the audit should record it as Unsupported rather than plan it again.
- Earlier work on this reader: `CR-OPENREADER-SHEETS` (row/column selection, formula results, hidden sheets; hidden sheets and row selection were not re-checked on a device) and CR-OWN-ENGINES E1c/E1d (borders, conditional formatting, notes, formulas, go to cell, freeze header).
- Verified 2026-11-11: app 264 tests and package 250 tests pass; analyze has no errors or warnings.

## Plan
1. INTAKE (this document).
2. CONTEXT: reconnaissance and behaviour audit, producing `agentic/data/project-context/features/CR-EXCEL-READER-AUDIT/AUDIT-REPORT.md`.
3. Stop for the user's approval of the prioritized gap list. No implementation before that.

## Progress

### Run stage history (2026-11-11)
INTAKE, CONTEXT, IMPACT and TECHNICAL results recorded and closed by the user; the technical gate was approved by `macdipu` (the user told the agent to run the approve command). Stage is IMPLEMENTATION. Plan: `agentic/data/project-context/features/CR-EXCEL-READER-AUDIT/TECH-SPEC.md` (approved as written, including first tap selects / second tap on the active cell opens the cell sheet).

### S1 selection core: code and tests done, uncommitted (package repo `../universal_document_viewer` and this repo)
Package:
- New `lib/src/spreadsheet/grid_selection.dart`: `GridSelection` (cell, range, row, column, all; anchor and active cell; `contains`, `bounds`, `address`, `extendedTo`), `columnLabel`. Exported from `spreadsheet.dart`.
- `SpreadsheetController`: `selection` (ValueListenable), `select`, `clearSelection`, `selectAll`, `moveSelection`, `moveSelectionTo`, `pageRows`, `revealCell`. Cleared when the sheet changes or a file loads.
- `SheetGeometry`: `visibleRowAtY`, `visibleColumnAtX`, `contentHeight`, `contentWidth`.
- `SpreadsheetView`: mouse press/drag selects, Shift+click extends, tap selects (touch), a second tap on the active cell opens the cell sheet; arrows, Shift+arrows, Tab/Shift+Tab, Enter, Home/End (Ctrl for the sheet corners), PgUp/PgDn, Ctrl/Cmd+A, Esc (only when something is selected); the corner selects all; active-cell border and range outline (borders, not colour alone); selection bar shows the address, size, count, sum and average; selection summary is cached per selection and rows, and ranges over 100,000 cells are not totalled. Cell, header and corner `InkWell`s no longer take focus (the grid keeps it).
- New strings: `selectAll`, `dimensions`, `rangeTooLargeToSummarize`, `selected`.
Tests: package 268 pass (was 250), analyze clean; app 264 pass, analyze 0 errors/0 warnings. New: `test/grid_selection_test.dart`, `test/grid_selection_view_test.dart` (12 widget tests incl. phone, tablet and desktop sizes, swipe does not select, virtualized far cells, sheet switch). Two existing tests changed for the approved tap behaviour: package `spreadsheet_view_test.dart`, app `excel_reader_controller_test.dart` (UX-32).

Known limits of S1 (to be closed in later slices or recorded in the final report):
- Keyboard moves do not treat a merged area as one cell; a click on a merged area selects its top-left cell.
- Copy for cell and range selections is S2 (the bar hides Copy for them); Ctrl/Cmd+C is S2.
- Touch range selection (long press, handles, auto-scroll, pinch) is S3; a touch tap selects one cell only.
- No on-device check yet; widget tests only.
- Found while testing: tapping a cell and scrolling it out of the grid while its ink splash runs trips a framework assertion in widget tests, on the original code too (probe run with S1 stashed). Tests turn the splash off; not fixed in the product.
- `Tab` is consumed only while something is selected, so keyboard focus can still leave the grid with no selection or after Esc.

### S2 copy and statistics: code and tests done, uncommitted
Package:
- `SpreadsheetController.selectedText()`: TSV (rows by newline, cells by tab), Excel-style quoting of cells holding a tab, line break or quote; one cell copies as it reads; whole row/column/select-all drop trailing blank rows and columns; null over `maxCopiedCells` (1,000,000).
- Ctrl/Cmd+C copies the selection (only when something is selected). The bar has Copy (TSV) and Copy address for every kind of selection.
- Every clipboard write (bar, keyboard, cell sheet value and formula) is awaited; a refusal shows "Could not copy..." instead of "copied". Strings go through `DocumentViewerStrings` (`copied`, `couldNotCopy`, `tooLargeToCopy`, `copyAddress`, `min`, `max`, `numbers`).
- Statistics: Count, Numbers (shown only when some cells are not numbers), Sum, Avg, Min, Max. Date/time cells are counted but never added; when every number shares one format the results use it (10% + 20% shows Sum 30%).
Tests: package 279 pass, analyze clean; app 264 pass, analyze 0 errors/0 warnings. New `test/grid_selection_copy_test.dart` (11). App UX-32 header test updated for the new bar wording ("Count 2 · Numbers 1 · Sum 97 · Avg 97 · Min 97 · Max 97").

### Housekeeping (2026-11-11)
The user asked to merge the worktree into main and code on main. The only worktree, `.claude/worktrees/agent-a414f7b607def1150` (branch `worktree-agent-a414f7b607def1150`, from an earlier session), had no commits beyond main and no changes; it was removed with `git worktree remove` and `git branch -d`. All S1/S2 work is on `main` in both repos, uncommitted.

### S3 touch selection: code and tests done, uncommitted
- Long press (touch only, not mouse) selects the cell and starts range mode, with a haptic. The same finger then drags to extend. In range mode a swipe extends instead of scrolling (scroll physics locked). Two handles (48 px hit area) move the top-left and bottom-right corners. Holding near an edge auto-scrolls and keeps extending. A bottom toolbar offers Copy, Copy address (icon) and Done. Done or Esc leaves range mode and keeps the selection.
- Pinch zoom with two fingers (0.75x to 2x); a pinch never selects.
- A normal swipe scrolls and never selects; a tap selects one cell.
- Bug found and fixed: the selection bar used to appear above the grid and push every cell down about 48 px on the first press, so drags landed a row off. It now sits below the grid (status-bar position), and pointer positions are recomputed from global coordinates on every move. Regression test added.
- Bug found and fixed: the touch toolbar overflowed on a 390 px phone.
Tests: package 288 pass, analyze clean; app 264 pass, analyze 0 errors/0 warnings. New `test/grid_touch_selection_test.dart` (8, phone portrait and tablet landscape).

### Commits (2026-11-12 check)
S1 to S3 are committed: package `efe5abe` (version 0.1.5), app `5399988`.

### S4 reading gaps, part 1: code and tests done, uncommitted (2026-11-12)
Package:
- `DocumentFormat`: `.xlsm` (excel) and `.tsv` (csv); MIME `application/vnd.ms-excel.sheet.macroenabled.12` and `text/tab-separated-values`. Macros are never read (the reader opens only the parts it draws).
- `.tsv` files split on tabs (no delimiter guessing); `.csv` still detects.
- `ZipSafetyGuard.isEncryptedOfficeFile`: OLE2 header plus an `EncryptedPackage` stream name. Only runs once a file already failed the ZIP check. An encrypted workbook now fails with `DocumentLoadError.passwordRequired`, a legacy `.xls` renamed `.xlsx` stays `corrupted`.
- `SpreadsheetController.hiddenSheetNames` (hidden, not very hidden, as Excel lists them).
- `Worksheet.unshown` / `UnshownContent`: drawings (pictures, charts, shapes), chart sheets, tables, pivot tables, data validation, conditional-formatting rules the reader can't evaluate (expression, timePeriod, iconSet), sparklines.
- Range hyperlinks: every cell of a linked range carries the link (budget 100,000 cells per sheet).
App:
- Password message: "This workbook is password protected. OpenReader can't open protected workbooks yet; try another app."
- Tab bar: "All sheets" button (bottom-sheet picker listing every sheet, then the hidden ones, greyed), "N hidden" chip; the bar shows when there are 2+ sheets or any hidden sheet.
- "Not shown: ..." notice above the grid, per sheet, dismissible (stays dismissed for that sheet while the reader is open).
- `.xlsm`/`.tsv` registered: Android intent filters (lowercase MIME), macOS Info.plist, Windows `register-file-types.ps1`. Not added to the "make default" type list (`DefaultAppService`, one type per format).
Tests: package 306 pass (new `test/sheet_reading_gaps_test.dart`, 18), analyze clean; app 270 pass (new `test/widgets/excel_reading_gaps_test.dart`, 6), analyze 0 errors/0 warnings.

### S4 reading gaps, part 2: code and tests done, uncommitted (2026-11-12)
Package:
- Search: `SheetSearchOptions` (matchCase, wholeCell, inFormulas, allSheets) on `SpreadsheetController.searchOptions`; changing them re-runs the search. `CellMatch.sheet` (optional, always set by search). All-sheets search covers visible sheets in order and starts at the first match on or after the sheet on screen; Next/Previous switch sheets. A sheet switch ends a one-sheet search and keeps an all-sheets one. Hidden rows, columns and sheets are skipped.
- Big workbooks (over 200,000 cells in scope) are searched in 50,000-cell slices between frames after a 200 ms pause; a newer query or clear cancels the older one; `isSearching` / `DocumentSearchState.isSearching` while running. Smaller ones stay synchronous (existing behaviour and tests).
- Timing check (test): 300,000 cells, all sheets: 208 ms total including the 200 ms pause, longest slice 2 ms (desktop test run).
- Frozen-pane jump: audit listed it as suspected Broken. Not reproduced: geometry already subtracts frozen panes. Regression tests added (file-frozen rows+columns at zoom 1 and 1.5, and "Freeze header row"). No code change.
- Wrapped rows: `SheetGeometry.fitWrappedRows` measures wrapped cells (TextPainter, column width minus padding) in rows the file gave no height and grows them, up to Excel's 409 pt. Stored heights, merged and hidden cells are left alone. Budget 2,000 measured cells per sheet (5,000 took 41 ms on the desktop test run). Cached per sheet in the controller.
App:
- Search options menu (tune icon) in the search status bar: Match case, Match entire cell, Search formulas, All sheets (only with 2+ sheets). The Excel reader defaults to all sheets, so the "Search in workbook" tooltip is now true; it reads "Search in sheet" when off. Label shows "Searching..." while a big search runs and "3 of 12 · Sheet2" for all-sheets results.
- Tapping a sheet tab still ends the search (now also an all-sheets one); stepping to a match on another sheet doesn't.
Tests: package 327 pass (new `sheet_search_test.dart` 14, `sheet_wrapped_rows_test.dart` 7), analyze clean; app 271 pass (search options widget test added to `excel_reading_gaps_test.dart`), analyze 0 errors/0 warnings.

Known limits of S4:
- Fitted row heights use the default font family and ignore the system text scale (cells already scale with it; rows didn't before either). Bottom-aligned text is still drawn centred (a deliberate earlier choice for taller touch rows).
- Search options are in the Excel reader only; the CSV reader keeps plain search.
- `.xlsm`/`.tsv` are not in the "make OpenReader the default app" list.
- Encrypted workbooks are detected, not opened (no decryption).

### S5 responsive layout (app): code and tests done, uncommitted (2026-11-12)
- New `lib/features/excel_reader/presentation/widgets/sheet_formula_bar.dart`: name box (active cell address), `fx` mark for formula cells, the formula (`=SUM(B2:B2)`) or full value; one line, "Show all" expands to a scrolling, selectable area. Reads `SpreadsheetController.selection`; the selection's size and totals stay in the grid's own status bar (no duplicate bar).
- Phone (compact width, or short height such as a phone on its side): name bar only while a cell is selected, 4 px grid frame, Favorite moves into More, read-only shown as a lock. Tablet and desktop: name bar always shown, "Read-only" chip spelled out, Favorite in the app bar. Body keeps clear of side insets (notches) in landscape.
- Breakpoints reuse `ScreenUtils` (`isCompactScreen`, `isShortScreen`); no new layout system.
- Test helpers moved to `test/helpers/excel_reader_harness.dart` (used by the S4 and S5 widget tests; tapped cells use `NoSplash`).
Tests: app 281 pass (new `test/widgets/excel_responsive_layout_test.dart`, 10: phone portrait/landscape, tablet both orientations, desktop; no overflow; name bar behaviour; formula; expand), analyze 0 errors/0 warnings. Package unchanged by S5.

Known limits of S5:
- The CSV reader keeps its old layout (no name bar or read-only mark).
- No on-device check yet.

### S6 accessibility (package): code and tests done, uncommitted (2026-11-12)
- Cell semantics: each cell says "B2, value 40, formula, link, has note, selected" (`DocumentViewerStrings.cellDescription`), as a button with tap and long-press actions. The name bar and selection bar already had labels.
- Keyboard focus ring: a 2 px primary border around the grid while it has focus and the user is on the keyboard (`FocusHighlightMode.traditional`); gone for pointer/touch. The active cell keeps its own border.
- Reduced motion: `jumpToCell` (search, go to, links) jumps instead of animating when the system asks for it (`accessibilityFeatures.disableAnimations`).
- Column-header row is 44 px at zoom 1 (new `SpreadsheetController.headerHeight`, was the 36 px row height); row headers are 48 wide. Applies at every size, not only touch.
Tests: package 331 pass (new `sheet_accessibility_test.dart`, 4), analyze clean; app 281 pass, analyze 0 errors/0 warnings.

Known limits of S6:
- Not tested with a real screen reader (TalkBack, VoiceOver, NVDA); only the semantics tree is asserted.
- Cells are individual buttons: a big grid is a long list for a screen reader; no row/column grouping or table semantics.
- Contrast of the selection fill and fitted themes not measured.

### Release preparation and platform check (2026-11-12)
- Package committed: `9ab6e68` (CHANGELOG entries under "Unreleased (0.2.0)"). CI steps run locally on the package: format, analyze, 331 tests pass. `dart pub publish --dry-run` warns only that pubspec says 0.1.5 while the changelog's top section is "Unreleased (0.2.0)": the version number is for the user to choose at release.
- macOS: debug build OK against the local engine; built Info.plist lists `xlsm` and `tsv`; the app launches and opens a window with the sample `.xlsm` (no visual check: screen capture only sees the terminal).
- Android (Pixel 4a emulator, debug APK): merged manifest has the `.xlsm` (lowercase MIME) and `.tsv` intent filters. Opened `budget.xlsm` and `data.tsv` through VIEW intents: read-only lock, 44 px headers, name bar, tap selects with "Count 1" status bar, "1 hidden" chip and sheet menu, workbook search "apple" jumped to the April sheet ("1 of 1 · April"), `.tsv` split into two columns.
- Not checked by hand: long-press range selection with handles, pinch zoom, copy to the clipboard, wrapped-row sheet, a real password-protected file, TalkBack/VoiceOver (emulator only, no physical phone connected).
- Gap seen: the CSV/TSV reader has no read-only mark and keeps Favorite in the app bar (known, not in scope).

### Cell look and density (CR-SHEET-CELL-UI), 2026-11-12
Implemented from `agentic/data/project-context/features/CR-SHEET-CELL-UI/AUDIT-AND-DESIGN-PROPOSAL.md` on the user's instruction. Summary and limits are at the end of that file; package CHANGELOG has the entries. Engine 349 tests, app 283. Behaviour changes to note at release: touch columns 104 px (was 110), row numbers 40 px (was 48), vertical cell padding 4 (was 2), selection drawn as a tint plus outline, and a desktop mouse gets compact 28 px rows.

Touch drag/select rework and mouse/keyboard on touch devices were added on 2026-11-12 (see the end of that proposal): handles on any tapped cell or range, scroll lock only while a finger holds a handle, no Done toolbar, grab-offset handle drags, haptic ticks; layout follows the pointer in use on every platform; Ctrl/Cmd +/-/0 zoom.

### Remaining (not started)
- S6 accessibility: cell semantics, focus ring, reduced motion, header touch targets.
- On-device check of S1 to S3 on the connected Android phone (only the user can operate it).
- Then: commit (both repos), IMPLEMENTATION result for the run, REVIEW/QA, package release and app pin bump (user approval).

## Status
IMPLEMENTATION. S1 to S3 committed. S4 to S6 done and uncommitted (both repos, on main). All approved slices coded. Next: on-device check by the user, commit, IMPLEMENTATION result, REVIEW/QA, release (needs approval). The Implementation result for the run is recorded once, when the slices the user wants in this run are done (operator closes the task).
