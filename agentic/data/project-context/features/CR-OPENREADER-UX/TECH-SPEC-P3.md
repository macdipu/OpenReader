# CR-OPENREADER-UX Phase 3: technical spec

Status: APPROVED and COMPLETED (2026-10-22). Released as v1.0.6+8, including revision 1 review fixes. ADR-OPENREADER-desktop-drop accepted.

## Baseline (v1.0.5)
- `flutter test`: 199/199 pass.
- `flutter analyze --no-fatal-infos`: 0 errors, 1 pre-existing warning (`settings_view.dart` unused `busy`), 145 infos.

## Constraints
- **No new dependency** except `desktop_drop`; see [ADR-OPENREADER-desktop-drop](adr/ADR-OPENREADER-desktop-drop.md).
- **Accessibility follows ODF-P5-08's decided approach:**
  - Flutter `Semantics` and tooltips only.
  - Additive changes; no widget restructuring.
  - Verified with `flutter test` semantics matchers.
- **The All Files Access permission stays** (ODF-P5-02). Only the copy changes.

## Implementation batches
The work is one run, implemented and tested batch by batch:
- **A: trust and copy.** UX-23, UX-24, UX-27.
- **B: shared UI.** UX-25, UX-28, UX-29, UX-30, UX-31.
- **C: readers.** UX-32, UX-33.
- **D: opening files.** UX-34, plus the ADR.

## Design

### A. Trust and copy
- **UX-23, privacy.**
  - The three "SANDBOXED" pills (Settings, Library, Files Info) become "OFFLINE", sharing one small widget.
  - Settings privacy section and File Information say that OpenReader:
    - reads documents across device storage using Android's All Files Access (desktop: the folders it scans);
    - keeps its index and history on the device;
    - never uploads files or makes network calls.
  - `docs/privacy.html` gets the same statements: All Files Access by name, the full-device index, and Firebase removed. It covers Android and desktop.
- **UX-24, File Information.**
  - The "Created" and "Page / sheet / slide count" rows are removed, since they are never populated.
  - The sandbox permission row is replaced by the access statement.
  - The "Local Only" verified badge becomes "Read on-device — OpenReader makes no network calls".
- **UX-27, desktop.**
  - **Onboarding** checks `PlatformInfo.isAndroid`. On desktop it shows a welcome variant: the same header and format chips, a one-line local/offline statement, and a single "Get started" button that runs the existing `continueWithoutAccess`-style completion and goes to the shell. There is no permission paragraph and no Allow button.
  - **Other copy:** Settings' "what Android granted" and the phone icon on the theme "System" option become platform-neutral (`Icons.brightness_auto_outlined`).

### B. Shared UI
- **UX-25, dates.** A new `formatDocumentDate(DateTime)` in `core/presentation/utils` uses `DateFormat.yMMMd()` with the device locale.
  - It replaces `toDMYString` in `DocumentListTile` and File Information, and the ISO date in `search_view.dart`.
  - `formatRelativeTime`'s fallback after 7 days also uses it.
  - The dead helpers are left untouched; removing them is out of scope.
- **UX-25, highlighting.** `DocumentListTile` gains an optional `highlight` query. When it is non-empty, the title renders as `Text.rich`, with case-insensitive matches styled in `secondaryContainer`. Search passes its query; Files passes its search text.
- **UX-28, snackbars.** `CustomSnackbar`:
  - `overlayBlur: 0` and no `overlayColor`.
  - Bottom margin = 16 + bottom-nav height (64) + safe-area inset while the shell's compact nav is showing; otherwise 16.
  - `title` becomes optional. When it is absent, the snackbar shows the message only, and the generic 'Success'/'Error'/'Info'/'Warning' titles are no longer added. Call sites that pass a document name keep it.
- **UX-29, empty states.** `CommonEmptyView` gains `icon`, `subtitle` and optional `actionLabel`/`onAction`, following the Files `_FilesMessage` pattern. It is scrollable, so it works inside a `RefreshIndicator`. Uses:
  - Favorites: star icon, "Star documents to keep them here", "Browse Files".
  - History: history icon.
  - Search initial: search icon.
  - Search no-results: "Clear filters" when a format filter is set.
  - Excel/CSV empty sheet: "This sheet is empty".
- **UX-30, accessibility (ODF-P5-08).**
  - A `tooltip:` on every `IconButton` the sweep listed: Home, Search, Files, File Information, the tile star, and all 5 readers' app bars and search bars.
  - The tile's `PopupMenuButton` tooltip becomes "More actions".
  - Format pills, theme segments, the PDF mode tiles and PDF thumbnails get `Semantics(button: true, selected: …, label: …)` wrappers.
- **UX-31, text scale.**
  - Fixed heights become `minHeight` constraints, or are scaled by `MediaQuery.textScalerOf(context).scale(1)` (clamped to ×2). This covers: the Home Continue Reading row (156) and its card, the search box (48), the chip rows (40), the nav bar (64), the Excel sheet tabs (44), and the File Information label column (120, which becomes flexible).
  - Grid cells scale with UX-32 zoom.

### C. Readers
- **UX-32, Excel/CSV grid.**
  - **Cell detail:** tapping a cell opens a bottom sheet with its address and full value, plus a Copy button (`Clipboard.setData`).
  - **Zoom:** −/+ buttons in a floating pill over the grid's corner set `zoom` between 0.75 and 2.0 in 0.25 steps, held in memory per reader session. *As built: in a pill rather than the app bar, which has no room for two more actions on a phone.* `CellGrid` multiplies cell width, height and font by it. The saved offsets are divided by zoom when saved and multiplied when restored, so rows and columns stay stable.
  - **Highlight:** the current match uses `tertiaryContainer`, and other matches use `secondaryContainer` at reduced alpha. Cell text uses `onSurface`, or black/white by contrast on a file-coloured cell. *As built: excel_plus reports black as the font colour for most cells, which would be unreadable in dark mode, so the file's font colour isn't used.*
- **UX-33, PDF reader.**
  - **Zoom:** zoom in, zoom out and fit-width buttons in the floating toolbar, using pdfrx `zoomUp`/`zoomDown` and `setZoom(centre, coverScale)`.
  - **Thumbnail strip:** gets a `ScrollController` and follows `currentPage` (an `ever` listener and `animateTo`, centred).
  - **Content clearance:** `PdfViewerParams.boundaryMargin` adds bottom space equal to the toolbar plus strip, so the last page isn't covered.
  - **Fullscreen:** a toolbar button toggles `isFullscreen`, which hides the app bar, toolbar and strip, and sets `SystemUiMode.immersiveSticky` on Android. Tapping the page shows the controls again. The mode is restored on close.
  - **Night mode:** an app-bar toggle, remembered in `AppSettingsRepository` (global), that wraps the viewer in a `ColorFiltered` inversion matrix. The thumbnails are inverted too.

### D. Opening files
- **UX-34:**
  - **Phone "Open file":** Home's app bar gets a ⋮ overflow on compact screens with "Open file", which calls `AppShellController.pickAndOpenFile`.
  - **Keyboard shortcuts:** `CallbackShortcuts` at the shell and in readers:
    - Ctrl/Cmd+O opens a file.
    - Ctrl/Cmd+F focuses search: Search screen from the shell, the reader's search inside readers.
    - Esc closes reader search, then the reader.
  - **Right-click:** `DocumentListTile` handles `onSecondaryTapDown` by showing the same actions as its ⋮ menu at the pointer position.
  - **Drag-and-drop:** per the ADR, `DropTarget` around the shell on desktop only, with a drop overlay. The first path goes to `IncomingIntentService.handlePath`.

## Impact
- **Modules:** core presentation (tile, snackbar, empty view, date util, offline pill), app shell, home, files, favorites, search, settings, onboarding, file_information, the 5 readers (tooltips; PDF and Excel/CSV features), the settings repository (PDF night mode), `pubspec` (`desktop_drop`), and `docs/privacy.html`.
- **No** schema or permission change.
- **Risk: medium**, because of the breadth: about 35 files and a new plugin. Main risks:
  - Drag-and-drop and keyboard behaviour can be verified only on desktop builds; the emulator is Android.
  - PDF fullscreen and system-UI restore.
  - Grid zoom and offset conversion.

## Tests
- **A:**
  - No "SANDBOXED" or "No broader filesystem access" text remains in widgets.
  - File Information has no placeholder rows.
  - The desktop onboarding variant has no Allow button.
- **B:**
  - `formatDocumentDate`.
  - Tile highlight spans.
  - Snackbar with no generic title.
  - `CommonEmptyView` action.
  - Semantics matchers: tooltips on reader app bars; `selected` on pills and segments.
  - The Home Continue Reading row doesn't overflow at text scale 2.0.
- **C:**
  - Grid zoom offset conversion.
  - Cell-detail sheet.
  - PDF thumbnail-follow and night-mode toggle at controller level.
- **D:**
  - The shortcut handlers.
  - The secondary-tap menu.
  - The drop handler routes the first path to `handlePath`.
- **Emulator QA** (Android) covers A-C plus phone "Open file". Desktop behaviour (drag-and-drop, shortcuts, right-click) needs a macOS build run on this machine.

## Revision 1 (2026-10-22): review fixes
These fix `validation/P3-review.md`. Approved in-session together with release 1.0.6.
- **Grid zoom.** `_zoom` is initialised in `initState`, so the first zoom stays anchored.
- **Night mode.** The PDF viewer and the thumbnail strip always sit inside one `ColorFiltered`, with an identity matrix when night mode is off. Toggling no longer rebuilds the viewer, and the thumbnails are inverted too.
- **Fullscreen system bars.** `SystemChrome` calls are made only on Android.
- **Snackbar margin.** It reserves `scaledExtent(64)` for the nav bar.
- **Copy.**
  - Settings no longer says "only reads"; it mentions deleting only when you choose Delete.
  - Onboarding no longer lists PowerPoint as readable (UX-07 is still open).
- **PDF clearance.** It now comes from bottom padding around the viewer (screen pixels) instead of `boundaryMargin` (document units, which scaled with zoom).
- **Esc and Ctrl/Cmd+F in fullscreen** leave fullscreen first.
- **Onboarding** `minHeight` is clamped at 0 or more.
- **Logged, not fixed:**
  - Android 15+ may ignore immersive mode.
  - The zoom pill can cover the last cells.
  - A drop while a reader is open opens on top (accepted: drops always open the file).
  - Unused network-capable packages remain in `pubspec`.
