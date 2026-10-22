# CR-OPENREADER-UX Phase 2, revision 2: independent review (2026-10-22)

The reviewer was a fresh independent subagent working read-only on the revision 2 diff over v1.0.4. The 4 touched controller test files pass.

## Findings
1. **CONFIRMED: Excel sheet switch.** `CellGrid(key: ValueKey(sheetIndex))` builds a new Scrollable at 0 without notifying listeners, so the cached offsets keep the previous sheet's values. A close within 2s saves them under the new `sheet_index`.
2. **PLAUSIBLE: text reader scroll-to-top.** Scrolling back to 0 after a saved 3000, then closing within 2s, saves nothing (`_lastScrollOffset > 0` is false), so the reader reopens at 3000.
3. **PLAUSIBLE: onboarding guard.** `_checkingAccess` resets once `offAllNamed` fires, and `allowAccess` ignores it, so a second resume or an Allow tap during the transition can finish onboarding again.
4. **Test gaps:** the Excel/CSV tests only cover seeded offsets, not the capture path or the sheet switch.

## No issue found
- The bold-merge removal (traced in `Text.build`; jumps need a query, so rows render via `Text.rich` with an explicit w400).
- The PowerPoint single signal.
- The CSV/Excel capture via `CellGrid` listeners.
- The text capture via the view listener.

## Outcome
The user approved revision 3: fixes for findings 1-3, plus tests for 1 and 2.
