# CR-OPENREADER-UX Phase 2: technical spec

Status: APPROVED (in-session, 2026-10-22), revision 1. Released as v1.0.4+6 by explicit user decision, with the known issues in `validation/P2r1-review.md`. The revision 2 fixes are pending, and the run is still at REVIEW.

## Baseline (2026-10-22, `08fe4b5`)
- `flutter test`: 162/162 pass.
- `flutter analyze --no-fatal-infos`: 0 errors, 2 pre-existing warnings (`settings_view.dart:441-442`, unused `destructive`/`busy`), 146 infos.

## Product decisions (user, 2026-10-22)
- **UX-08:** a row tap opens the document everywhere. The Files action sheet moves to long-press.
- **UX-09/10:** keep the History tab and delete the Recents route. The tab is titled "Library", and Clear History shows only on the History tab.
- **UX-12/13:** split Home's recents. Continue Reading shows 1-3 documents, with PDF progress; the Recent rows show the rest.
- **UX-15:** no undo, but destructive styling.
- **UX-19:** the PDF view mode is remembered per document.

## Design

### Shared
- **New `showConfirmDialog({title, message, confirmLabel, destructive})`** in `core/presentation/widgets/show_dialog/`.
  - It returns `true` only on confirm.
  - With `destructive`, the confirm button uses `colorScheme.error`.
  - Used by delete (UX-15) and by Clear History on both the Library tab and Settings (UX-16).
- **New `StorageAccessService.requestOrOpenSettings()`.** It calls `requestAccess()`. If that fails and the permission is permanently denied, it calls `openSettings()`. It returns whether access is granted.
  - Used by Home's permission banner, the new Files Grant Access button (UX-17), and the interaction controller's "Grant Access" snackbar actions.
- **New `readingProgress(RecentDocumentModel)` helper** (domain extension).
  - For PDFs it returns `page_number / page_count` when both are positive ints; otherwise null.
  - Other formats return null, because there is no meaningful denominator.

### UX-08: row tap
- Files: `onTap` calls `interactions.openDocument`.
- `DocumentListTile` gains an optional `onLongPress`, which Files passes to `_showFileActionSheet`. Other screens are unchanged.

### UX-09/UX-10: one history surface
- **Tab controller.** `FavoritesController` mixes in `GetSingleTickerProviderStateMixin` and owns a `TabController(length: 2)`, replacing `DefaultTabController`. An `isHistoryTab` Rx is updated by a listener and disposed in `onClose`.
- **Navigation.** New `AppShellController.openHistory()` calls `changeTab(favoritesIndex)`, then `FavoritesController.showHistory()`, which animates to tab 1. Home's "See All" calls it.
- **Title and action.** The tab is titled "Library", and the SANDBOXED pill stays. The Clear History action is wrapped in `Obx` and shown only when `isHistoryTab` is set.
- **Removed:** `AppRoutes.recents`, its `GetPage`, `RecentsView` and `RecentsBinding`. `RecentsController` stays and backs the History tab.

### UX-11 / UX-14: Home chips and tune icon
- The "All" chip passes `selected: false`. The chips are shortcuts into Files, not a filter state on Home.
- The decorative tune icon is removed from `_SearchBarStub`.

### UX-12 / UX-13: Home layout and progress
- **Data.** `_maxRecentPreview` goes from 5 to 8.
- **Continue Reading** shows `recents.take(3)`. The header row carries "See All", which calls `openHistory`.
- **Recent Documents** shows `recents.skip(3)`, and is hidden when there are three or fewer recents. There are no duplicates.
- **Progress:**
  - The `_ContinueReadingCard` gains a 3px progress bar when `readingProgress` is non-null.
  - Home's rows and the History tab's rows pass `progress: readingProgress(recent)` to `DocumentListTile`.
- **PDF saving.** The reader's `_savePosition` now stores `{page_number, page_count, view_mode}`. A position saved before this release has no `page_count`, so it shows no bar until the PDF is reopened.

### UX-15: destructive delete
- `confirmAndDelete` uses `showConfirmDialog(destructive: true)` and keeps the "cannot be undone" copy.
- The tile overflow "Delete" item and the Files sheet "Delete" row are styled with `colorScheme.error`. `_SheetAction` gains a `destructive` flag.

### UX-16: Settings Clear Recent History
The settings tile calls `showConfirmDialog(destructive: true)` before `clearRecentHistory`. If the tile has an unused `destructive` parameter (`settings_view.dart:441`), it is wired up, which removes one existing warning.

### UX-17: Files empty and no-access states
- **No access:** an icon, the message, and a "Grant Access" button. The button calls `FilesController.requestAccess()`, which uses `requestOrOpenSettings` and then `load()`.
- **Empty:** the view is wrapped in a scrollable `RefreshIndicator`, so pull-to-refresh works.
  - With no filter or query: "No documents found", plus a "Scan storage" button that calls `refresh()`.
  - With a filter or query active: "No matching documents", with no scan button.

### UX-18: denied permission and resume
- **Home banner** uses `requestOrOpenSettings`.
- **`AppShellController`** mixes in `WidgetsBindingObserver`, added in `onInit` and removed in `onClose`.
  - On `resumed` it reads `hasAccess()`.
  - For each registered Home or Files controller whose `hasAccess` differs, it calls `load()`.
- **`OnboardingController`** does the same: on resume in `denied` or `permanentlyDenied` with access now granted, it finishes onboarding exactly like the granted path.

### UX-19: per-document PDF view mode
- **On open:**
  - If the saved position has `view_mode`, use it.
  - Otherwise apply the Settings default.
  - Either way, skip it if the user already toggled; a `_modeChosenByUser` flag fixes the late-read race.
- **On toggle:** set the flag and save the position, including `view_mode`.

### UX-20: text reader preferences
- `AppSettingsRepository` gains `getTextReaderFontSize`/`setTextReaderFontSize` (default 14) and `getTextReaderLineWrap`/`setTextReaderLineWrap` (default true). These are global, as the obvious default.
- `TextReaderController` takes an injectable settings repository.
  - It loads both values in `onInit`; a user change made before the read completes wins.
  - The setters persist the new value.

### UX-21: exact jump-to-match (no new dependency)
- **Measurement.** New `TextLineMetrics` in `text_reader/presentation` measures each line with `TextPainter`:
  - inputs: the reader's `TextStyle`, `TextScaler`, the content width (viewport minus 32px horizontal padding), and the wrap flag;
  - each line adds 4px of vertical padding;
  - offsets are cached as incremental prefix sums, and the cache is invalidated when the style, width or wrap changes;
  - with wrap off, every line has the same height, so the offset is O(1).
- **Wiring.**
  - The view's `LayoutBuilder` sets `controller.lineOffsetResolver`.
  - `_jumpToLine` uses the resolver when it is set. Otherwise it falls back to the old estimate, as it does in controller tests without a view.
  - `_approxLineHeight` stays only as that fallback.

### UX-22: Word reader position restore
- **Restore.**
  - `WordReaderController` owns a `ScrollController`, disposed in `onClose`.
  - The view wraps `DocxView` in `PrimaryScrollController(controller:, automaticallyInheritForPlatforms: all platforms)`. `DocxView`'s controller-less vertical `SingleChildScrollView` then inherits it.
  - `onLoaded` calls `controller.onDocumentLoaded()`. After a post-frame callback, that jumps to `initialScrollOffset`, clamped to `maxScrollExtent`.
- **Save fix.** The `NotificationListener` saves only notifications from the vertical axis at depth 0, so horizontal table scrolls no longer overwrite the saved offset.
- **Docs.** The controller's doc comment is updated; it currently describes restore as impossible.

### F6a/F6b + HOME-GUARD: load-session guard on refresh
- **Files `refresh()`:**
  - It takes `session = ++_loadSession`, then calls `beginLoad()` and the rescan.
  - On failure:
    - if the session is still current: `handleFailure`, then set `_retryScan = true`;
    - if a newer load started meanwhile: an error snackbar only, so the newer results stay.
  - On success: `load()`, so post-scan data replaces any pre-scan filter result.
- **Home** gets the same `_loadSession` in `load()` and `refresh()`, with a check after each await. `isScanning` stays true for the whole rescan, regardless of interleaved loads.

### HOME-RECENTS: refresh after closing a reader
- `DocumentInteractionController` gains `readerClosed` (an `RxInt`).
  - `openDocument` keeps returning without waiting for the reader.
  - It chains `.then((_) => readerClosed.value++)` onto each reader route's `Get.toNamed` future.
- `HomeController` and `RecentsController` subscribe in `onInit` with `ever(...)` when the interaction controller is registered, and call `load()`. The workers are disposed in `onClose`.

## Impact
- **Modules:**
  - `core/presentation`: tile, dialog, interaction controller.
  - `core/domain`: progress helper, settings repository interface.
  - `core/data`: settings repository implementation.
  - `services/utilities/storage_access_service`.
  - `app/shell`.
  - `res/routes`: the recents route is removed.
  - features `home`, `files`, `favorites`, `recents` (view and binding deleted), `settings`, `onboarding`, `pdf_reader`, `text_reader` and `word_reader`.
- **No** schema change, new dependency, or platform/manifest change.
- **Data:**
  - The PDF reading-position JSON gains `page_count` and `view_mode`; the column is free-form JSON, so older rows stay readable.
  - New SharedPreferences keys are added for the text reader.
- **Risk: medium**, given the breadth (about 25 files). The riskier pieces:
  - **UX-22** relies on `DocxView` inheriting a `PrimaryScrollController`. It is verified from the 1.0.4 source and must be checked on the emulator.
  - **UX-21** has a `TextPainter` measurement cost on the first long jump in a very large file. It is O(lines up to the target) and cached afterwards.

## Tests
New or updated:
- **Files:**
  - Tapping a row opens the document; a long-press shows the sheet.
  - The empty state has Scan storage and is pull-refreshable.
  - The no-access state's Grant Access button calls the service, then `load`.
  - Refresh failure after a newer load keeps the results (F6a), and Retry after a refresh failure rescans (F6b).
- **Home:**
  - "All" is not selected, and the tune icon is gone.
  - With 5 recents: 3 cards and 2 rows, with no duplicates.
  - The PDF card shows progress.
  - "See All" opens the Library on History.
  - A load interleaved with a scan doesn't overwrite it (HOME-GUARD).
  - `readerClosed` triggers a Home reload.
- **Library:** the title is "Library", and Clear History is visible only on the History tab.
- **Delete:** the confirm button is error-coloured; cancel doesn't delete.
- **Settings:** Clear Recent History asks first, and cancel keeps the history.
- **Readers:**
  - PDF: the saved `view_mode` wins over the default; a late default doesn't override a user toggle; the save includes `page_count` and `view_mode`.
  - Text: font and wrap are loaded and persisted.
  - `TextLineMetrics`: offsets match a laid-out `ListView` in a widget test, for wrap on and off.
  - Word: offset save filtering and the restore call (controller level).
- **Emulator QA:** UX-22 restore, UX-21 jump, UX-18 resume after granting in system settings, and the UX-08/09/12 flows.

## Revision 1 (2026-10-22): review fixes
The run was reopened after the independent review (`validation/P2-review.md`). Technical approval was re-recorded in-session.
- **HOME-RECENTS ordering.** Readers notify `DocumentInteractionController.historyChanged()` (which bumps `readerClosed`) from `onClose`, after their final `markOpened` completes, or right away when there is nothing to save. This covers PDF, Word, Text, Excel and CSV. `_openReader` no longer bumps on route pop.
- **Scan banner.** Home counts in-flight rescans, and `isScanning` turns false only when the last one ends.
- **Onboarding.** The resume re-check sets `requesting` before awaiting `hasAccess()`, and restores the denied state if access is still missing.
- **Bold text.** Text measurement merges `FontWeight.bold` when `MediaQuery.boldTextOf` is set, as `Text` does.
- **Tests:**
  - Closing a real reader controller reloads Home only after its save.
  - The metrics test measures against the real `TextReaderView` rows.
