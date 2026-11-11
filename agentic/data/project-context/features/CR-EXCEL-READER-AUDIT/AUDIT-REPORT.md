# Excel Reader audit report (CR-EXCEL-READER-AUDIT)

Date: 2026-11-11. Run `RUN-6780549E98B74690B709F92E03DE3083`. Nothing has been implemented.

## How this was verified, and what was not
- **Done:** static reading of the app (`OpenDocs/lib`) and the engine package (`universal_document_viewer/lib/src`, own repo). The headline findings were re-checked by grep. App tests (264) and package tests (250) pass; analyze has no errors or warnings.
- **Not done yet:** running the app on desktop, tablet and phone sizes, and reproducing the bugs on a device. Every "Missing" below is confirmed in code; every "Implemented" is from reading the logic plus existing tests, **not yet re-checked on a device**. The device pass is step 1 of the plan below and must finish before the status of any "Implemented" row is final (the request forbids marking a feature implemented from code alone).
- **Not read in full:** the style/theme-colour code, `incoming-intent` format gate, test bodies of `document_views_test.dart`.

Packages: `PKG` = `universal_document_viewer/lib/src`, `APP` = `OpenDocs/lib`.

## Headline
The reader renders workbooks well (parser, number formats, borders, conditional formatting, merges, freeze panes, virtualization). **It has no cell or range selection.** A cell tap opens a detail sheet; the only selection is a whole row or column from its header (`GridSelection`, `PKG/spreadsheet/spreadsheet_view.dart:518`). There is no keyboard navigation, drag, shift/ctrl, long-press, handles, pinch zoom, Ctrl/Cmd+C, context menu, sort or filter, CSV export or print. The layout is the same at every screen size.

## Feature inventory
Status: I Implemented, P Partial, M Missing, B Broken, U Unsupported. Priority only for gaps.

### Open and read (request section 4)
| Requirement | Status | Pri | Where / notes |
|---|---|---|---|
| .xlsx, .csv | I | | `PKG/common/document_format.dart` |
| .xls | U | | Deliberately excluded; backlog `CR-LEGACY-OFFICE` |
| .xlsm | M | P1 | Not in the extension map, so picker/drop reject it. Parser never touches `vbaProject`, so read-only open is safe; needs the extension, a test, and a "macros not run" note |
| .tsv | M | P1 | Not accepted as an extension; the CSV reader already detects tab delimiters |
| Picker, desktop drop | P | | `APP/app/shell/app_shell_controller.dart:131`, `app_shell.dart:143`. Drop opens the first file only |
| Loading / progress | P | P2 | Spinner only; parse runs in `Isolate.run` |
| Corrupt file | I | | Mapped to "may be damaged" |
| Password-protected | P | P1 | Encrypted xlsx is OLE2, fails ZIP guard, shows the generic "damaged" message |
| Size limits | I | | 200 MiB file, CSV 20 MiB, 1,048,576 rows, 16,384 cols, 10M cell slots |
| Original never modified, macros never run | I | | Read-only path; no explicit macro test |
| Multiple / empty / sparse sheets | I (unverified on device) | | |
| Hidden sheets | P | P1 | Left out of the tabs entirely; request wants a hidden-sheet indicator, not silent omission |
| Metadata (name, sheets, size) | P | P2 | Not audited in detail |
| Merged cells, hidden rows/cols, freeze panes | I | | `_mergesOf`, `SheetGeometry`, pane element + freeze-top-row toggle |
| Hyperlinks | P | P1 | Safe (http/https/mailto only; explicit tap). Range links only mark the first cell; `launchUrl` failure not handled |
| Comments / notes | I | | Legacy notes with corner marker |
| Images, charts | M | P2 | No drawing parsing. Must show a clear "not shown" indicator (P1) |
| Formula result + text | I | | `FormulaValue`, cell sheet shows formula |
| Unsupported-feature notice | M | P1 | No indication for images/charts/data validation/tables/expression rules |

### Grid and rendering (section 5, 11)
| Requirement | Status | Pri | Notes |
|---|---|---|---|
| Virtualization | I | | `TableView.builder` |
| Row numbers, column letters | I | | Pinned headers |
| Types, number formats, currency, %, dates | I | | `number_format.dart` |
| Fills, text colour, bold/italic/underline/strike, borders, alignment, wrap | I | | |
| Font family | M | P2 | |
| Row height for wrapped text | P | P1 | Stored heights; wrapped text clips; vertical "bottom" drawn centred |
| Gridline / heading toggles | M | P2 | |
| Zoom | P | P1 | Toolbar 0.75x to 2x; no pinch, no Ctrl+wheel |
| Fit to width | M | P2 | |
| Sheet tabs | P | P1 | No overflow menu or sheet picker; hidden-sheet marker missing |

### Selection (section 6)
| Requirement | Status | Pri |
|---|---|---|
| Select a cell, range, drag, shift-click, shift+arrows | M | P0 |
| Ctrl/Cmd-click disjoint | M | P2 |
| Active cell vs range visuals, address / range address (B2:D5), dimensions | M (header selection shows only "Row 3" / "Column B") | P0 |
| Row / column header select | I (single, toggled; never verified on a device, see CR-OPENREADER-SHEETS) | |
| Select all | M (corner is inert) | P1 |
| Clear selection | I | |
| Keyboard nav: arrows, Tab, Enter, Home/End, PgUp/PgDn | M (only Ctrl/Cmd+F and Esc exist, `APP/core/presentation/widgets/app_shortcuts.dart`) | P0 |
| Right-click context menu | M | P1 |
| Touch: long press, drag, handles, auto-scroll, contextual toolbar, pinch | M | P0 (mobile) |
| Statistics | P: Count, Sum, Avg only; no numeric count, min, max. Mixed types handled (numbers only). Formatted % / date values summed as raw numbers, which can mislead | P1 |
| Reset on sheet change | I (view re-keyed per sheet) | |

"P0" here follows the request's definition (core selection and navigation not working). Because selection was never built, this is a missing core capability rather than a regression.

### Copy (section 7)
| Requirement | Status | Pri |
|---|---|---|
| Single cell | I | |
| Row / column | P: newline-joined, not TSV; one at a time | P1 |
| Range as TSV | M | P0 (needs selection) |
| Ctrl/Cmd+C | M | P0 |
| Clipboard failure feedback | B: `Clipboard.setData` not awaited at `spreadsheet_view.dart:394, 438, 648`, success snackbar shown regardless | P1 |
| Copy address | M | P1 |
| Copy formula | I | |

### Search and navigation (section 8)
| Requirement | Status | Pri |
|---|---|---|
| Search current sheet, highlight, count, next/prev | I | |
| Workbook-wide search | M (tooltip says "Search in workbook" but only the active sheet is searched: misleading label, B) | P1 |
| Formula search, case-sensitive, exact | M | P1 |
| Large-sheet responsiveness | P/hazard: synchronous scan per keystroke on the UI isolate, no debounce; formats numbers on every call | P1 |
| Go to address (`D120`, `Sheet2!B3`) | I | |
| Return to previous location | M | P2 |
| A found match can land under frozen panes (`jumpToCell` ignores pinned offsets) | B (suspected) | P1 |

### Sort and filter (section 9): M. No autofilter parsing, no view sort, no indicators. P2 per this audit's judgement (secondary to selection); user to confirm.

### Layout (section 10)
| Requirement | Status | Pri |
|---|---|---|
| Desktop toolbar, formula bar, name box | M: no formula/cell bar; value shown in a modal sheet | P1 |
| Read-only indicator | M | P1 |
| Tablet / phone layouts | M: one layout everywhere, no breakpoints in the sheet views | P1 |
| Bottom contextual toolbar on selection | M | P1 (with selection) |
| Safe areas | P: tab bar only | P2 |
| Dark mode | I | |

### Export and print (section 12): M. No CSV export, no print, no "download original" (Share and Open With exist). P2; file-save of the original needs a decision.

### Performance (section 13)
1. Search runs synchronously per keystroke (hazard).
2. `SelectionSummary.of` recomputed on every controller notification over whole columns, on the UI thread.
3. `List<List<SheetCell?>>` padded rows up to a 10M-slot budget; the parsed workbook is copied back from the isolate.
4. 20 MiB CSV parsed with a character loop.
5. `_mergesOf` up to 200k map entries; a post-frame callback is registered on every build.
No benchmark on a large workbook has been run yet.

### Accessibility (section 14)
Headers have semantics labels; data cells have none. No focus nodes or indicators in the grid. `jumpToCell` always animates (no reduced-motion check). Header cells are 20 to 30 px tall, below 48 dp. Toolbar tooltips exist.

### Security (section 15): I
Links never auto-open and are scheme-allowlisted; no cell contents logged; ZIP guard in place; XML parsed by event reader (DTD handling not confirmed; add a test). No upload of workbook data.

## Other defects found
- Selection and copy strings in the package are hard-coded English although `DocumentViewerStrings` exists.
- Excel and CSV views duplicate the app bar, search bar and error view (`excel_reader_view.dart`, `csv_reader_view.dart`). Not in scope to refactor.
- `ReaderScrollbar` reaches package-internal controllers with an `ignore: invalid_use_of_internal_member`.

## Architecture and constraints
- One grid (`SpreadsheetView`, `two_dimensional_scrollables`); no second grid in the app. The app mirrors package state through `SheetReaderController`.
- Selection must be built **once, in the package**, in `GridSelection`/`SpreadsheetController` shared state, then surfaced by the app toolbar. No second selection engine.
- Package changes happen in `../universal_document_viewer`, followed by a version bump and a bump of the app's git pin (release approval is the user's, and the package's 0.2.0 is already unreleased).
- Library limits to document: `.xls` (U), pictures/charts (parser does not read drawings), expression conditional formats, font families, no recalculation (cached values only).

## Recommended implementation order (needs approval)
1. **Device audit pass** (desktop, tablet, phone portrait/landscape; large-workbook timing). No code.
2. **Selection core** (P0), package-side: single cell, range, active cell vs range, address bar, keyboard nav and Shift+arrows, mouse drag, shift-click, select all, header select as range; shared with the existing row/column selection. Tests: selection logic, virtualization, sheet switch, zoom.
3. **Copy and stats** (P0/P1): range as TSV, Ctrl/Cmd+C, awaited clipboard with failure feedback, copy address, numeric count/min/max with format-aware stats; selection stats off the build path.
4. **Touch selection** (P0 mobile): long-press range mode, handles, edge auto-scroll, exit control, contextual bottom toolbar, pinch zoom, swipe-vs-select rules.
5. **Reading gaps** (P1): `.xlsm` and `.tsv` extensions, password-protected message, hidden-sheet indicator, unsupported-feature notice, workbook search plus case/exact/formula options, async/debounced search, frozen-pane jump fix, wrapped row height, hyperlink ranges, tab overflow.
6. **Responsive layout** (P1): formula/name bar, read-only indicator, tablet and phone layouts, safe areas.
7. **Accessibility** (P1/P2): cell semantics, focus indicators, reduced motion, touch target sizes.
8. **P2:** sort/filter view, CSV export of sheet/range, print, gridline toggle, fit to width, font family, return-to-previous.

## Decisions needed from the user
1. Confirm the order and that selection is built in the package (new package version, release approval yours).
2. Sort/filter, export and print: P2 as above, or promote?
3. `.xlsm` and `.tsv`: accept the extensions (parser stays macro-free)?
4. "Download original": add a save-to-folder action, or keep Share and Open With?
