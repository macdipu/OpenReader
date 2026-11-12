# Spreadsheet cell UI: audit and design proposal (mobile and desktop)

Status: IMPLEMENTED on 2026-11-12 on the user's instruction ("complete all these, finish"), with the recommended defaults for the open questions (44 px touch headers; compact density for a mouse on desktop; ghost grid; view-only column resize; selection colour from the format accent, falling back to the theme's primary). See "Implementation result" at the end. The audit and proposal below are unchanged.
Scope: the Excel/CSV/TSV grid (`SpreadsheetView` in `../universal_document_viewer`, wrapped by the app's Excel and CSV readers). Read-only product: editing is out of scope (see "Editing").

**About the request.** The pasted task was cut off in the middle of Phase 2 ("8. Touch"), so any later phases (desktop brief, acceptance criteria, deliverables) were not seen. Phase 1 and a mobile proposal follow the text that arrived; a desktop proposal is added because the task asks for both. Please send the missing part if it changes anything below.

**Evidence and its limits.** Cell facts come from reading the code (file:line below) and from screenshots of the debug build on the Android emulator (Pixel 4a, 1080x2340) on 2026-11-12. I could not capture the macOS window (screen capture only sees the terminal), so desktop findings are from code and widget-test sizes, not from pixels. Findings marked (code) were not reproduced on screen.

---

## Phase 1: Audit

### 1. Cell rendering (`spreadsheet_view.dart`, `sheet_geometry.dart`, `cell_border.dart`)

| Aspect | Today | Verdict |
|---|---|---|
| Default column width | 110 px (`SheetGeometry.defaultColumnWidth`, 8.43 chars); file widths scale from it | 1.7x Excel's 64 px. Fine on desktop, shows only ~3 columns on a 390 px phone |
| Default row height | 36 px (`defaultRowHeight`), same on phone and desktop; file heights scale `36 x pt / 15` | Right for touch. On desktop it shows about half the rows Excel does (a 900 px window holds roughly 19 rows against Excel's ~35) |
| Header row / row-number column | 44 px tall (S6), 48 px wide; bold 12 px; fill `surfaceContainer`; selected header is a solid `primary` fill | Selected header is heavy; 44 px costs vertical space on desktop |
| Padding | 6 px horizontal, 2 px vertical | Tight vertically for 13 px text; fine horizontally |
| Font | 13 px at Excel's 11 pt (`fontPixelsOf`); file sizes scale; min zoom 0.75 gives about 9.8 px | Below ~11 px at minimum zoom: hard to read on a phone |
| Gridlines | 0.5 logical px, `outlineVariant`, on every side of every cell, so neighbours overlap | Hairline looks right at 2-3x pixel ratio. At 1x (many desktop monitors) 0.5 px renders inconsistently (code) |
| Backgrounds | File fill, else none (the page background) | Good fidelity |
| Alignment | Horizontal from the file or by type (numbers right, booleans/errors centre). Vertical "bottom" (Excel's default) is drawn centred, deliberately, because rows are taller than Excel's | Fine; recorded as a known choice |
| Overflow | Unwrapped text: one line, `TextOverflow.ellipsis`. Wrapped: clipped, rows now grow to fit (S4) | **Numbers and dates are ellipsized too (code):** "1,234,5…" can be misread as a smaller number. Excel shows `###`. No spill into empty neighbouring cells, which Excel does for text |
| Empty cells | Nothing drawn if the row ends; blank cells inside the data are drawn with gridlines | **Small datasets look unfinished.** See the screenshots: a 2x4 or 4x2 sheet is a small table in a large blank panel with a hard edge, right and below |
| Selection fill | `primaryContainer` fill, `onPrimaryContainer` text, 2.5 px active border, 2 px range edges | **Heavy in this app's light theme:** `primaryContainer` is dark navy, so the selected cell (and a whole selected row) becomes a dark block that hides its own fill and text colour. Seen on the emulator |
| Match highlight | Theme-driven (`DocumentViewerTheme`), current vs other | Good |

### 2. Interaction

| Aspect | Today | Gap |
|---|---|---|
| Single click/tap | Selects the cell (S1) | Good |
| Double tap/click | A second tap on the active cell opens the cell sheet (link, formula, note). No true double-click handling | OK; document it. Desktop could open details on double-click and keep Enter |
| Editing | None, by scope | Not a gap. See "Editing" |
| Multi-cell | Drag, Shift+click, header click, corner, long-press range with handles, auto-scroll (S1, S3) | Good. No Ctrl+click multi-range (not needed read-only) |
| Copy | Ctrl/Cmd+C, bar buttons, TSV (S2). Paste: n/a | Good |
| Keyboard | Arrows, Shift+arrows, Tab, Enter, Home/End, PgUp/PgDn, Ctrl+A, Esc (S1) | Merged cells move as individual cells (known) |
| Mouse extras | None: no hover cursor, no context menu, no cell hover state, no column resize or autofit, **no scrollbar inside the grid** (the app adds one with `ReaderScrollbar`; other users of the package get none) | Desktop gaps |
| Touch | Tap, long-press range, handles, pinch 0.75-2x, swipe scrolls | Works; no haptic on plain tap; handles clear but selection tint is heavy |

### 3. Responsive behaviour

| Question | Mobile (390x844, verified on emulator) | Desktop (1440x900, by code) |
|---|---|---|
| Dimensions appropriate? | Rows yes. Columns: 3 visible, a 4th would hint at scroll | Rows too tall (about 19 visible), columns fine |
| Uses the screen? | Grid fills width; a small file leaves blank space right and below with no grid continuation | Same, and worse: a 3-column file occupies a quarter of the width |
| Small datasets complete-looking? | No | No |
| Scrolling | Natural; swipe scrolls, long press selects, no conflict seen | Wheel and touchpad scroll; no visible scrollbar in the package view |
| Readable text? | 13 px at 1x; below 11 px when zoomed out | Fine |
| Touch/scroll conflicts | None found; range mode locks scroll on purpose | n/a |

### 4. Architecture (what to preserve)

- One grid: `SpreadsheetView` + `SpreadsheetController` (selection, search, geometry, zoom). The app adds only chrome (app bar, name bar, tabs, toolbar). Keep this split.
- Sizes are constants on `SheetGeometry` (`defaultColumnWidth`, `defaultRowHeight`, padding, `fontPixelsOf`) and `SpreadsheetController` (`headerHeight`, `rowHeaderWidth`, `cellHeight`). **They are static, so density cannot vary by device without refactoring them into an instance value.** This is the main structural obstacle.
- Colours come from `Theme.of(context).colorScheme` (no spreadsheet-specific tokens except match highlights in `DocumentViewerTheme`).
- Breakpoints live in the app (`ScreenUtils`: compact < 600, expanded >= 1024, short height < 500). The package has none.
- Selection is `GridSelection` in `SpreadsheetController.selection`; cells read it per build. No editing state exists.

---

## Phase 2: Proposal

### Principles
1. Keep the data model, geometry maths, selection engine and gestures. Change presentation and add one density setting.
2. Density follows the input device, not only the width: a touch laptop or an iPad with a mouse should not flip layouts.
3. Never rely on colour alone for selection (borders stay).
4. Small datasets should look like a spreadsheet, not a cut-off table.

### Sample images (inspiration only, not the target look)

The user supplied two sample images: (1) a phone spreadsheet screenshot (a Sheets-style editor, 320 px wide) and (2) an annotated Excel desktop mock-up. They are **examples, not a design to copy**: the proposal below comes from the audit, and the samples are listed only as ideas it may borrow. The right-hand column says which idea is worth considering; none is decided until the proposal is reviewed.

| Seen in a sample | Today | Idea to consider |
|---|---|---|
| Grid runs to the screen edge; empty rows and columns keep light gridlines (mobile rows 1-17 are blank but gridded; Excel shows blank gridded columns past the data) | Data ends in a hard edge, blank panel beyond | Ghost grid (B.3, C.6): the samples show it, which supports the idea, not decides it |
| Selected range: pale blue tint, 2 px blue border round the whole range, text and fills stay readable | Dark navy block (`primaryContainer`) | Tint over the cell's own fill + outline (B.1) |
| Active cell: same range border, with round dot handles at the top-left and bottom-right corners (about 10 px drawn, much larger hit area); Excel shows a small square at the active cell's corner (the fill handle) | Handles exist (48 px hit area), drawn as larger discs; no marker on a single active cell | Smaller handle dots (about 10-12 px, hit area unchanged at 48 px). No fill handle (read-only). Whether a single selected cell should show corner dots is an open question |
| Selected column/row headers: darker grey fill, Excel adds an accent underline on the column header and a rounded outline round the selected row numbers | Solid `primary` block | Quieter header highlight (B.2): subtle fill + accent bar on the inner edge instead of a solid block |
| Headers: light grey, centred, regular weight, narrow row-number column (about 14% of a 320 px width) | Bold 12 px on `surfaceContainer`, 48 px wide | Lighter fill, weight 600 to 500, row header 40 px on touch |
| Very light gridlines; white cells | `outlineVariant` hairline | Keep hairline, 1 physical pixel |
| Overlay scroll thumbs (a small grey pill at the bottom and right edge) on mobile; a thin horizontal scrollbar on desktop | None inside the grid on mobile; none in the package on desktop | Overlay scroll thumbs on touch, a draggable scrollbar on desktop (C.2) |
| Excel: separate **name box** (with a drop-down arrow) and **formula bar** (`fx` + formula) above the grid | One joined box, no drop-down; name is not interactive | Optional: split into name box + formula field, and let tapping the name box open Go to cell (the existing dialog) |
| Excel: green accent for the active cell border, selected header underline, active sheet tab | Theme `primary` (blue/navy) in the grid; the app already uses a green accent for the Excel tab | Optional: selection colour from the format accent through a new `DocumentViewerTheme.selectionColor`, instead of `colorScheme.primary` (see question 6) |
| Excel: sheet tabs with a green underline on the active one, a `+` button | Tabs done (green underline already) | No `+` (read-only) |
| Mobile editor chrome: undo/redo, formatting bar, add-row, text-format toolbar | None, by scope | Not considered: all of it is editing. The read-only equivalent stays: the contextual bottom toolbar (Copy, Copy address, Done) |

### A. Density (new): `SheetDensity { touch, compact }`, `SpreadsheetView(density: auto)`
`auto` = `touch` on Android/iOS (and on desktop while the last pointer was touch or pen), `compact` on desktop OS with a mouse. Lives on the controller or view as an instance value that `SheetGeometry` receives instead of reading statics.

| Token | Mobile / touch | Desktop / compact |
|---|---|---|
| Default row height | 36 (unchanged) | 28 |
| Default column width | 96 (was 110; shows 3.5 columns on 390 px, so the edge hints that it scrolls) | 100 |
| Column header height | 44 (keeps S6) | 28 |
| Row header width | 40 (was 48) | 44 |
| Cell padding H/V | 8 / 4 | 6 / 2 |
| Base font | 13 px, never below 11 px after zoom (raise `minZoom` or clamp the font) | 13 px |
| Header font | 12 px, weight 600 | 12 px, weight 600 |
| Gridline | 1 physical pixel (`1 / devicePixelRatio`), not 0.5 logical | same |

File-specified row heights and column widths keep scaling from the new default; density only changes the default and the chrome.

### B. Mobile cell UI
1. **Selection.** A pale tint of the selection colour (the format accent, about 14% alpha) over the cell's own fill, so fills and text stay readable; a 2 px accent border round the whole range (not each cell); the active cell inside a range keeps its own 2 px border and no tint, so it reads as "where the keyboard is". Two small dot handles (10-12 px drawn, 48 px hit area) at the corners on touch. A selected row or column tints its cells the same way. (Colour and handle details are open to review; the samples are one possible look.)
2. **Headers.** Lighter fill (`surfaceContainerLow`), centred, weight 500. A selected column/row header gets the accent at 18% fill, accent text, and a 2 px accent bar on its inner edge (underline for a column header, side bar for a row header), instead of a solid block. Headers stay pinned.
3. **Complete-looking small sheets.** Draw a "ghost" grid (gridlines only, at about 40% opacity, no text, not selectable) to the viewport edge when the data is smaller than the viewport. It is a background painter behind the table, so no model or geometry change.
4. **Touch.** Keep tap = select, long press = range, handles 48 px, pinch zoom. Add a light haptic on selection start (already on long press), and keep the contextual bottom toolbar (Copy, Copy address, Done).
5. **Numbers.** Never ellipsize a number or date: if it doesn't fit, show `#` fill as Excel does (the full value is in the name bar and cell sheet).
6. **Scroll behaviour.** Unchanged: one-finger swipe scrolls; range mode locks scroll; the status bar sits below the grid. Add small overlay scroll thumbs (fade out after about 1 s) at the right and bottom edge.
7. **Name box.** Tapping the address in the name bar opens Go to cell; a chevron marks it as tappable.

### C. Desktop cell UI (also needed; the paste's desktop part was not received)
1. Compact density above (28 px rows: about 30 rows in a 900 px window instead of 19).
1a. Optional: name box with a drop-down arrow (opens Go to cell) and the `fx` formula field beside it, if the reviewer likes the split.
2. A visible scrollbar inside `SpreadsheetView` (vertical and horizontal, shown when the pointer is over the grid), so the package works without the app's wrapper.
3. Pointer affordances: basic cursor on cells, resize cursor on column header borders; hover tint on a cell (`onSurface` at 4%), none on touch.
4. Right-click menu: Copy, Copy address, Copy as TSV, Details. Double-click a cell opens its details (Enter does the same); keep first click = select.
5. Column widths: double-click a header border to auto-fit and drag to resize, **view-only** (not saved to the file; reset on reload).
6. Ghost grid as in B.3, filling the wide window.

### D. What does not change
Read-only scope, `GridSelection`, copy/TSV, search, hidden-row/column handling, frozen panes, number formats, borders and fills from the file, the app's name bar, tabs and toolbar.

### Editing
Out of scope by the product (read-only). If editing is wanted later it needs a scope decision (formula engine, undo, save path) before any UI. This proposal adds no edit affordances.

---

## Files that would change (for estimating)

Package: `sheet_geometry.dart` (instance density, fitted heights use it), `spreadsheet_controller.dart` (header height, row header width, density), `spreadsheet_view.dart` (selection colours, header style, ghost grid painter, scrollbars, cursors, context menu, number overflow), `cell_border.dart` (pixel-ratio gridline), `document_viewer_theme.dart` (`selectionColor`, overlay-scrollbar and ghost-grid tokens), `document_viewer_strings.dart` (menu strings). App: `excel_reader_view.dart` and `csv_reader_view.dart` to pass density and the accent as `selectionColor`, drop their own scrollbar wrapper, and `sheet_formula_bar.dart` for the split name box and Go-to tap. No change to `workbook.dart`, `xlsx_reader.dart`, `grid_selection.dart`.

## Risks
- Static-to-instance refactor of the size constants touches every geometry caller (about 15 sites) and many tests that assume 36 and 44.
- Mixed input devices: `auto` must not flip density mid-gesture; recompute only between interactions.
- Ghost grid and hover tint must stay cheap on virtualized, million-row sheets (paint only the viewport).
- 28 px desktop headers lower the S6 touch target (44 px) on desktop; acceptable because they are mouse-driven (WCAG 2.2 AA target size is 24 px), but a touch laptop gets `touch` density under the rule above.

## Suggested order
- P0: selection colours and header tint using the format accent (largest visible defect), pixel-ratio gridline, ghost grid, numbers never ellipsized.
- P1: density setting with desktop compact, mobile column width 96 / row-header 40, in-grid scrollbar, hover and cursors.
- P2: right-click menu, view-only column resize/auto-fit, text spill into empty neighbours (hard with virtualization), golden images.

## Verification plan
Widget and golden tests at 390x844, 820x1180, 1440x900 in light, dark and AMOLED; assertions on row/column counts visible per size; selection contrast check (WCAG 3:1 for the border against the cell); emulator and macOS screenshots before and after; large-sheet frame timing with the ghost grid on.

## Questions for the reviewer
1. Keep 44 px column headers on touch (recommended), or go to 40 to save vertical space?
2. Should desktop with a mouse always use compact density, even in a narrow window?
3. Is a ghost grid acceptable, or should small sheets be centred or left alone?
4. Is view-only column resizing wanted, or does it suggest editing?
5. The rest of the paste (desktop brief and acceptance criteria) is missing: what did it say?
6. Selection colour: the format accent (Excel green; teal for CSV), the existing theme colour, or something else? (Not decided by the samples.)
7. Should a single selected cell show corner dots on touch (one sample does)? They invite dragging to extend, which we already support.
8. What look do you want instead of, or beyond, these samples?


---

## Implementation result (2026-11-12)

Engine (`../universal_document_viewer`): `SheetDensity` / `SheetMetrics` (new `sheet_density.dart`), density-aware `SheetGeometry` and controller (auto density by device, top row kept on change), lighter selection with `selectionColor`, quieter highlighted headers, 12 px handle dots, ghost grid painter, `#` for numbers that do not fit, scrollbars (`showScrollbars`), hover tint, view-only column resize and auto-fit, right-click menu, one-pixel gridlines, 11 px text floor. Tests: engine 349 pass (new `sheet_cell_ui_test.dart`, 18), analyze clean, CI format check clean.
App: the format accent (Excel green, CSV teal) passed as `selectionColor`; the app's own scrollbar wrapper removed from the Excel and CSV readers (the grid draws its own); the name box opens Go to cell (arrow marks it). Tests: app 283 pass, analyze 0 errors/0 warnings.
Checked on the Android emulator (screenshots): ghost grid fills the view, tinted selection with outline, highlighted headers with bars, accent colour, name box drop-down. macOS: builds; no screenshot possible, so compact density is verified by widget tests only.

**Not done, and why:**
- Text spilling into empty neighbouring cells: needs knowledge of neighbours while the grid is virtualized; left out as high-risk for the gain.
- Golden-image tests: font rendering differs between macOS and the Linux CI, so they would fail there; behaviour is asserted instead (decoration colours, sizes, a rendered-pixel check of the ghost grid).
- A fill handle, corner dots on a single selected cell, a `+` sheet tab: editing-related or undecided (questions 7, 4).
- Open questions 2 and 8 were decided by default as above; reverse them by passing `density:` or `selectionColor:`.

### Changes made after reviewing the running apps (2026-11-12)
Reviewed on the Android emulator (a realistic 8-column, 60-row orders sheet) and the macOS app (real mouse events, window captures at 800x632 and 1400x880). Fixed:
- **Text room on phones:** the proposed 96 px / 8 px padding cut common names ("Alex Morg...", "Docking s...") shorter than the old layout. Touch is now 104 px columns with 6 px side padding (92 px of text; was 98 px at 110 px columns). Proposal table value "96" is superseded.
- **Focus ring after a mouse click (desktop):** a desktop is always in "traditional" focus mode, so a green frame surrounded the grid after every click. The ring now shows only after a key press.
- **Right-click flipped the desktop to touch rows:** a menu opening sends a cancel event that Flutter marks as touch. Only a finger lifting (a pointer-up) switches density now.
- **Grey active cell under the mouse:** the framework's grey hover wash on the InkWell showed through; replaced by an accent hover tint, skipped on the active cell.
- **Blank strips beside a small sheet (desktop):** the ghost grid now runs under the scrollbar gutters, and its lines are a little stronger.
- **Empty name box:** shows "Select a cell" until a cell is chosen (tablet and desktop).
- **Touch selection and dragging (user request):** (1) handles were only available after a long press and the grid stayed locked until "Done" was pressed; a tapped cell or range now shows handles at once, a swipe scrolls with a selection showing, and the Done toolbar is removed. (2) A handle sits on a cell corner and the cell under the finger was used, so picking one up could shift the selection; the corner now follows the finger from where it touched down, and a small inward nudge picks the cell the corner belongs to. (3) A light haptic tick per cell the selection grows by. (4) The status bar keeps its Copy / Copy address / Clear buttons in every state.
- **Mouse and keyboard on touch devices (user request):** density, the scrollbar gutter and the resize handles followed the platform, so an Android tablet with a mouse stayed in the touch layout. They now follow the input in use on every platform (hover switches to compact, a finger lifting switches back); a mouse never shows handles; Ctrl/Cmd with +, - and 0 zoom. Not done: Ctrl + mouse wheel zoom (the scroll view takes the wheel first), and no physical mouse-equipped device was available (tested with simulated pointers).
Not changed: the file-dependent app-bar and tab layout; no tablet device was available to try.
