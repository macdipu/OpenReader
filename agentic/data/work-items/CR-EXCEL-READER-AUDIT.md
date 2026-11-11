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

### Remaining (not started)
- S4 reading gaps: `.xlsm`/`.tsv` extensions, password-protected message, hidden-sheet indicator, unsupported-feature notice, workbook-wide search with case/exact/formula options run off the UI thread, frozen-pane jump fix, wrapped row heights, range hyperlinks, sheet picker for many tabs.
- S5 responsive layout (app): formula/name bar, read-only indicator, phone/tablet/desktop layouts.
- S6 accessibility: cell semantics, focus ring, reduced motion, header touch targets.
- On-device check of S1 to S3 on the connected Android phone (only the user can operate it).
- Then: commit (both repos), IMPLEMENTATION result for the run, REVIEW/QA, package release and app pin bump (user approval).

## Status
IMPLEMENTATION. S1, S2 and S3 code and tests complete, not committed (both repos, on main). Next: S4 (reading gaps). The Implementation result for the run is recorded once, when the slices the user wants in this run are done (operator closes the task).
