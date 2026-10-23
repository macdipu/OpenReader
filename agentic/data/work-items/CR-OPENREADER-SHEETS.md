# CR-OPENREADER-SHEETS: multi-sheet Excel fixes, row/column selection, reader search focus

## Requests (user, 2026-10-23)
- "continue if any remaning": device QA of 1.0.8 found that the readers' search fields opened without focus.
- "exl sheet with mutiple sheet": QA of a 5-sheet workbook.
- "for exlc clum and row select": select a whole row or column.

## Findings and changes
1. **Search field never got focus (all readers).** `AppShortcuts` holds `Focus(autofocus: true)`, and Flutter skips a later `autofocus` while another node in the same scope has focus. Fixed by wrapping the child in its own `FocusScope` (`lib/core/presentation/widgets/app_shortcuts.dart`). Keys still bubble to the shortcuts. Test: `ux_phase3_test.dart`, which fails without the fix.
2. **Formulas showed their text (`SUM(Sales!F…`) instead of results.** `excel_plus`'s `displayText` returns the formula even when the file has a saved result. New `CellText.readerText` shows the saved result, number-formatted, or `=formula` when there is none. Used by the grid, the cell detail sheet and search in both the Excel and CSV readers. Test: `test/core/cell_text_test.dart`.
3. **Sheet tabs were drawn under the Android gesture bar.** `_SheetTabBar` now uses `SafeArea(top: false)`.
4. **Hidden sheets were shown as tabs.** Now left out, as Excel does, unless every sheet is hidden. Test in `excel_reader_controller_test.dart`.
5. **New: row/column selection.**
   - Tap a column letter or row number to select it; tap it again or press ✕ to clear.
   - Cells are highlighted.
   - A bar shows `Count · Sum · Avg`. Sum and Avg cover numbers only, as in Excel's status bar.
   - Copy copies the values one per line, with trailing blanks dropped.
   - Headers have semantics labels ("Column B", "Row 2").
   - Lives in the shared `CellGrid`, so the CSV reader gets it too. Widget test in `excel_reader_controller_test.dart`.

## QA (emulator, Pixel 4a)
Done on a 5-sheet workbook:
- Formulas show 6440 and 200.
- Tabs sit above the gesture bar.
- Hidden sheet: before the fix it showed as a tab; after the fix it is covered by the unit test only, not rechecked on the device.
- Column F: Count 5 · Sum 6440 is correct.

Row selection on the device was interrupted: another user was using the emulator, so it is verified by tests only.

## Status
Implemented. Full suite passes (235 tests), and flutter analyze shows no errors or warnings. Released 2026-10-23: the user asked to "commit with new release tag", so this was committed and tagged v1.0.9 (1.0.9+11), not pushed. Still to do: re-check on a device that hidden sheets are left out and that row selection works.
