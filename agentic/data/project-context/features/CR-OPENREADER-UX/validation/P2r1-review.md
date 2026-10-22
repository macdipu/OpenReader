# CR-OPENREADER-UX Phase 2, revision 1: independent re-review (2026-10-22)

The reviewer was a fresh independent subagent working read-only. It ran the 82 tests in the four touched test files, and all passed. Emulator spot checks were done by the implementer.

## Findings (open; the user chose to stop here on 2026-10-22)
1. **CONFIRMED: the bold-text measurement is wrong on the jump path.**
   - Jumps only happen with a search query, and then rows render via `Text.rich` with an explicit regular-weight child style, so they are never bold.
   - `TextLineMetrics` measures them bold when the system Bold Text setting is on, so jumps overshoot.
   - Proposed fix: remove the bold merge (`text_reader_view.dart` `_attachMetrics`).
   - Minor: `Text` also applies MediaQuery line-height, letter-spacing and word-spacing overrides, which the metrics ignore.
2. **CONFIRMED (pre-existing bug, now exposed): readers save their close position after the scroll view detaches.**
   - **Text reader:** the scroll position is unavailable by then, so nothing is saved and the pending 2s debounce is cancelled. Scrolling in the last 2s before close is lost. *Reproduced on the emulator:* after a scroll followed by back within 0.5s, `qa-long.txt` reopened at the previous position (L350).
   - **Excel/CSV:** `_savePosition` writes row, column and offsets as 0 when no clients are attached, which can overwrite the saved position on close.
   - Proposed fix: cache the last-known offsets from the scroll callbacks and save those on close, as the Word reader already does.
3. **PLAUSIBLE: the PowerPoint stub** (`openDocument` default branch) calls `markOpened` without signalling `readerClosed`, so Home and History don't refresh.
4. **PLAUSIBLE, minor: onboarding resume re-check flickers.** It sets `requesting`, which briefly swaps the denied UI for a spinner. Proposed fix: a private guard flag instead of the status.

## No issue found
- `readerClosedAfter` fires exactly once, and only after the save lands.
- Worker disposal.
- The `_activeScans` counter, which can't leak because `rescan` can't throw.
- Load-session consistency.
- PDF view-mode chaining.

## Emulator QA so far (revision 1 build)
Pixel 4a emulator:
- **Passed:**
  - Home: no chip selected, no tune icon, Continue Reading with See All, no duplicates at 3 recents.
  - Files: tap opens the reader (UX-08); long-press shows the sheet with a red Delete; the delete confirm dialog has a red Delete and the "cannot be undone" copy (UX-15).
  - UX-21: a "NEEDLE" search lands L350 exactly at the top across hundreds of wrapped lines.
- **Not yet run:** UX-22 Word restore, UX-19/13 PDF mode and progress, UX-09/10 Library, UX-16 Settings confirm, UX-18 resume.
