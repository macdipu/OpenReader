# CR-OPENREADER-UX Phase 3: independent review (2026-10-22)

The reviewer was an independent subagent working read-only. `ux_phase3_test` passes.

## Confirmed
1. `CellGrid`'s `late _zoom` is lazily initialised, so the first zoom has ratio 1 and isn't anchored (on every new grid, including sheet switches).
2. PDF night mode switches between a `ColorFiltered`-wrapped and a bare `PdfViewer`. That rebuilds the viewer, which jumps back to the opening page and zoom.
3. Night mode doesn't invert the thumbnails, although the comment and the spec say it does. The strip is outside the filter.
4. PDF fullscreen calls `SystemChrome.setEnabledSystemUIMode` unawaited on desktop, which throws an uncaught `MissingPluginException`.
5. The snackbar reserves a fixed 64 for the nav bar, which is now `scaledExtent(64)` (up to 128), so it overlaps at large text sizes.
6. Settings copy says "It only reads them", but the app can delete files.
7. Onboarding says it reads PowerPoint, which has no reader.

## Plausible
- `boundaryMargin` is in document units, so it scales with zoom; at fit-width zoom the clearance is too small.
- `immersiveSticky` may be ignored on Android 15+ (target SDK 36).
- Esc in fullscreen closes the reader, and Ctrl+F opens a hidden search.
- A drop while a reader is open opens a second reader on top.
- The zoom pill covers the last cells.
- A title-less snackbar keeps an empty title slot.
- Onboarding `minHeight` goes negative on a tiny window.
- Unused network-capable packages remain in `pubspec`.

## No issue found
- AppShortcuts focus behaviour.
- `CommonEmptyView` bounded parents.
- CellGrid offsets at 1x, Obx placement and header sync.
- `onGeneralTap` semantics, worker disposal, `FittedBox`.
- Date initialisation cost and the `bn` mapping.
- `highlightMatches`, the right-click menu position, the Home ⋮ menu.
- Semantics and tooltips.
- macOS drop (no sandbox).

## Outcome
The user approved fixing confirmed findings 1-7, plus the PDF clearance, Esc/Ctrl+F in fullscreen, and the onboarding clamp. The other plausible items are logged.
