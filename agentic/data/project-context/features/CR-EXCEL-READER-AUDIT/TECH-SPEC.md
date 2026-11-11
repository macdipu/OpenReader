# CR-EXCEL-READER-AUDIT: technical plan

Basis: `AUDIT-REPORT.md` (same folder). Approved order: user, 2026-11-11, "approve the order, go ahead". Defaults used for the questions the user did not answer: sort/filter, export and print stay P2 (not in the first slices); `.xlsm`/`.tsv` are accepted (part of approved step 5); "Download original" stays as Share / Open With.

## Constraints
- Read-only. No editing, recalculation, new spreadsheet library or second selection engine.
- One grid: `SpreadsheetView` in `universal_document_viewer` (own repo `../universal_document_viewer`). Selection is built there, once; the app surfaces it. Package releases and the app's git pin need the user's approval at RELEASE.
- Public API additions only; `GridSelection.row/column` and `SelectionSummary` keep working.

## Slice S1: selection core (package)
- Move selection state from `_SpreadsheetViewState._selection` to `SpreadsheetController.selection` (a `ValueListenable<GridSelection?>`), so toolbars and the app read it. It is cleared when the sheet changes (the view is already re-keyed per sheet) and kept across zoom and scroll (it is stored in sheet coordinates, never in pixels).
- `GridSelection` gains `range` (anchor, active, extent), `cell`, and `all`; `row`/`column` stay and also give an active cell. `contains(row, column)` stays O(1).
- Interaction (desktop): a tap selects a cell; a **second tap on the active cell opens the existing cell sheet** (link, formula, note), so nothing is lost; drag selects a range; Shift+click extends; header click selects a row/column (Shift extends over headers); the corner selects all; Esc clears. Keyboard: a `Focus` on the grid; arrows, Tab/Shift+Tab, Enter, Home/End, PgUp/PgDn, Shift+arrows, Ctrl/Cmd+A. Moves go through hidden rows/columns and merged cells (a merge acts as its top-left cell), and scroll the active cell into view, offset by frozen panes.
- Display: a distinct active-cell border and a light fill with a boundary for the range (never colour alone: a border and a bar label), the address bar showing `B2` / `B2:D5 · 4R × 3C`.
- Tests: selection logic (pure unit tests), drag/shift/keyboard widget tests, virtualization (select far cell after scrolling), sheet switch clears, zoom keeps the selection.

## Slice S2: copy and statistics (package + app)
- `SelectionSummary` takes any `GridSelection`; adds numeric count, min and max; stats computed off the build path (once per selection change, not per controller notification) and skipped for mixed or text-only data.
- Copy a range as TSV (rows by newline, columns by tab, quoting as spreadsheets expect for tabs/newlines), Ctrl/Cmd+C, copy address, copy formula. `Clipboard.setData` is awaited; on failure show the error (replaces the unconditional "copied").
- Strings through `DocumentViewerStrings` (replace the hard-coded English).

## Slice S3: touch (package)
- Tap selects; **long press** starts range mode (haptic), then drag extends; two draggable handles (at least 44 dp) at range corners; edge auto-scroll while dragging; an explicit exit control (Done) and Esc. Outside range mode a one-finger swipe scrolls and never selects. Pinch zoom via a `ScaleGestureRecognizer` that only claims two-finger gestures, same 0.75x to 2x clamp. Contextual bottom toolbar (Copy, Copy as text, Details, Clear) shown while a selection exists.
- Risk: gesture arena conflicts with `TableView`'s scrollables. Mitigation: range mode toggles `physics` to `NeverScrollableScrollPhysics` and handles hit-test above the table; covered by widget tests with `TestGesture`.

## Slice S4: reading gaps
`.xlsm` (read-only, no macro execution, test with a macro-bearing fixture) and `.tsv` in the extension map, picker, drop and intent filters; password-protected message (OLE2 header sniff to `passwordRequired`); hidden-sheet indicator; "not shown" notice for images, charts, tables and expression rules; workbook-wide search with case, exact and formula options, run off the UI thread or in chunks with a debounce; frozen-pane offset fix for jump-to; wrapped row heights; range hyperlinks; sheet picker/overflow for many tabs.

## Slice S5: responsive layout (app)
Formula/name bar (address, formula indicator, value; long values scroll or expand), read-only indicator, breakpoints: phone (compact header, collapsible info panel, contextual bottom toolbar, safe areas), tablet (wider toolbar, both orientations), desktop (toolbar plus name bar). Reuse existing adaptive layout helpers (`adaptive_layout_test.dart` exists); no duplicate toolbars.

## Slice S6: accessibility
Semantics for cells and selection ("B2, value 40, selected"), visible focus ring, reduced-motion check in `jumpToCell`, header cells at least 44 dp tall at the touch breakpoint.

## P2, not scheduled
View-only sort and filter, CSV export of sheet/range, print, gridline/heading toggles, fit to width, font family, return-to-previous location.

## Verification per slice
`flutter analyze` and `flutter test` in the package and the app (baselines: 250 and 264 passing); new tests listed per slice; widget tests at phone (390x844), tablet (820x1180 and landscape) and desktop (1440x900) sizes; a large-workbook timing check before S2 stats and S4 search are called done; on-device spot check on the connected Android phone, which only the user can interact with.

## Risks
Behaviour change: a first tap no longer opens the cell sheet (second tap does). Package/app version coupling (package 0.2.0 is unreleased and the app pins git `main`). Gesture conflicts (S3). Existing tests that tap cells to open the sheet will need updating, with each change noted.
