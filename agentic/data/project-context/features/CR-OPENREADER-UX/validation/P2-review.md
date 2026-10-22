# CR-OPENREADER-UX Phase 2: independent review (2026-10-22)

The reviewer was an independent subagent working read-only on the uncommitted Phase 2 diff over `08fe4b5`. It ran 141 tests across the touched test files, and all passed.

## Findings
1. **CONFIRMED (GetX 4.7.3 traced): Home and History reload before the reader's final save.**
   - `DocumentInteractionController._openReader` bumps `readerClosed` in `Get.toNamed(...).then`, which runs as soon as the route pops.
   - Each reader's `onClose` save runs about 300ms later, on route dispose.
   - Effect: a PDF closed within 2s of a page turn leaves Continue Reading and History one page stale.
2. **PLAUSIBLE: overlapping rescans hide Home's scan banner early.** If the auto-scan and a pull-to-refresh overlap, the first rescan to finish sets `isScanning=false`.
3. **PLAUSIBLE: onboarding can finish twice.** The resume re-check leaves the denied state only after `await hasAccess()`, so two resumes can both pass.
4. **PLAUSIBLE: text measurement ignores the bold-text setting.** `TextLineMetrics` doesn't merge the accessibility `boldTextOf`, as `Text` does.
5. **Test gaps:**
   - The metrics test builds its own rows rather than the reader's.
   - The Word test uses a stand-in scroll view.
   - The HOME-RECENTS test bumps the counter directly, so it can't catch finding 1.

## No issue found
- The Library `TabController` lifetime. The shell's `IndexedStack` keeps the view alive.
- `openHistory` before the Library tab has been visited.
- Observer pairing.
- The Files/Home load sessions, `_retryScan`, and the auto-scan session check.
- Worker disposal.
- PDF view-mode precedence and `progress` guards.
- The text preference race flags, and the style, width and scaler parity of the measurement.
- Word reader:
  - `DocxView` adopts the primary controller.
  - The inner page view is shielded by `PrimaryScrollController.none`.
  - Search jump uses `ensureVisible`.
  - The `onLoaded` timing and the depth filter are correct.
- No references to the removed Recents route remain.
- The confirm dialog treats dismiss as cancel.

## Outcome
The user re-approved the design with fixes for findings 1-4 and the test gaps (revision 1).
