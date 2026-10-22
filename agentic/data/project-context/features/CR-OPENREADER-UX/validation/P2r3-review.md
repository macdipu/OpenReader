# CR-OPENREADER-UX Phase 2, revision 3: quick independent re-check (2026-10-22)

The reviewer was an independent subagent working read-only. It read the code and ran no tests.
1. **CONFIRMED (narrow): re-tapping the current Excel sheet tab** calls `switchSheet` and resets the cached offsets with no rebuild or scroll. A close within 2s then saves 0.
   - Also noted: the reset comment is inaccurate, because `CellGrid` jumps newly shown sheets to the offset restored at open.
2. **Clean: the text reader's `_scrolledThisSession`.** The restore jump can't save a pre-layout 0. A clamped estimated extent saving a smaller offset predates this change.
3. **PLAUSIBLE, minor: `continueWithoutAccess` isn't latched**, so a double-tap, or a tap during the finish, navigates twice.

## Outcome
The user chose to fix both with no further independent re-review (revision 4).
