# Foldables and dual-screen devices (Galaxy Z Flip / Z Fold, Pixel Fold, Surface Duo)

Status: plan only, nothing implemented. Written 2026-10-30.

## What exists today

- Layout is width-based: `ScreenUtils` (`lib/core/presentation/utils/screen_utils.dart`) uses compact < 600dp,
  medium 600-1023dp, expanded >= 1024dp. `AppShell` shows a bottom bar when compact, a sidebar otherwise.
- `MainActivity` handles `screenSize|smallestScreenSize|screenLayout|orientation|density` itself, so folding or
  unfolding does not restart the activity. Good.
- `main.dart` locks portrait **once at startup** if the shortest side is under 600dp.
- No use of `MediaQuery.displayFeatures`, so a hinge or fold is invisible to the layout.

## Problems this causes on foldables

1. **Fold started closed, then unfolded.** The Fold's cover screen (~360dp) counts as a phone, so portrait is locked
   for the life of the process. Unfolding to the ~673dp inner screen keeps a portrait lock on a tablet-sized display.
   Android 16 ignores such locks on large screens, and Play expects large-screen apps not to be locked.
2. **Flip cover screen** (about 3.4 inch, roughly 720x748 px): the home UI will not fit. It needs either no support
   (the app is not shown there by default, which is fine) or a tiny glanceable view. Recommendation: do nothing there.
3. **Unfolded Fold / Pixel Fold / Surface Duo:** the width lands in the medium band. The sidebar plus a 960dp
   content cap works, but two panes would use the space far better, and a hinge can cut through content.
4. **Flex mode (Flip half-open, "tabletop"):** a reader can sit in the top half with controls on the bottom half.
   Without fold awareness the toolbar can end up across the crease.

## Plan

### P1: fix correctness (small, do first)
- Replace the one-time portrait lock with a live rule: lock only while the window's shortest side is under 600dp,
  and release it when the window grows. Listen on `WidgetsBindingObserver.didChangeMetrics` and call
  `SystemChrome.setPreferredOrientations` accordingly.
- Verify no state is lost on fold and unfold (reader position, search, selection) with `resizeableActivity`
  left at its default (true).
- Add the Android manifest property `PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY` only if needed. It likely is not.

### P2: hinge-aware layout
- Read `MediaQuery.of(context).displayFeatures`. Treat a `DisplayFeature` of type `fold` or `hinge` as the split line.
- Wrap each page in `DisplayFeatureSubScreen` where a feature is `separating`, and keep text, tiles and dialogs out
  of the hinge band. `Flutter`'s own dialog and route code already respects it when wrapped.
- Add `ScreenSize` helpers: `isTabletop` (a horizontal fold, half-open) and `isBook` (a vertical fold).

### P3: two-pane on large inner screens
- Home / Library: list on the left, **document preview or reader on the right**. On a fold, put the list on one
  side of the hinge and the reader on the other (Surface Duo style), otherwise a fixed 360-420dp list pane.
- Reader chrome: move the bottom floating toolbar to the half of the screen that has no content when tabletop.
- Keep the phone bottom bar when compact; keep the desktop sidebar from medium up. Do not show both.

### P4: continuity and input
- Keep reading position and scroll while folding (readers already persist position; verify).
- Drag a document between panes is out of scope for now.
- Large-screen input: keyboard shortcuts already exist for desktop. Check they work with a Fold plus keyboard and
  with S Pen hover. No new feature needed.

### P5: test matrix
- Android emulator "7.6 Fold-in with outer display", "Resizable (Experimental)", and Pixel Fold.
- Samsung Remote Test Lab for a real Z Flip / Fold (Flex mode and Flex panel).
- Cases: cold start folded then unfold; cold start unfolded then fold; rotate while unfolded; split-screen next to
  another app; multi-window with two OpenReader windows (single-top launch mode means a second tap on a file reuses
  the window; decide if that is acceptable).

## Acceptance
- No portrait lock on any window whose shortest side is 600dp or more, at any time in the process lifetime.
- No content under the hinge in book and tabletop postures.
- Reader state survives fold and unfold.
- Two-pane Home or Library on an unfolded Fold; bottom bar on the Flip main screen and any phone.

## Open questions
- Is the Flip cover screen worth a dedicated glance view (recent file name and page)? Default answer: no.
- Should the reader open in the right pane by default, or full screen with a back button as on phones?
