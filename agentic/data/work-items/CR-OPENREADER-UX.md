# CR-OPENREADER-UX: UX audit remediation

## Request and routing
- **Requested:** 2026-10-21. The user asked for a full-codebase UX audit, a gap list and a plan to fix it, then said "continue … start working".
- **Input mode:** prompt-first. The audit was run in-session by reading every screen, reader and shared widget under `lib/`. It is a code read only; nothing was run on a device.
- **Work type:** `change_request` (brownfield).
- **Hierarchy:** CR → phase-scoped Tasks. Sprint handling is `NO_REPLAN`, because each phase is independently shippable and has no cross-phase dependency.
- **Runs:**
  - Phase 1 is `RUN-634FD576573D433995F3E16CB7BE4B57`.
  - Phases 2 and 3 get their own runs once Phase 1 is released.
- **Preceding work:** TASK-008 (`FEATURE-OPENREADER-P1`) was superseded by the user on 2026-10-21; it was never formally reviewed.

## Current Behavior
See the full gap inventory below (UX-01…UX-34, severity-ranked). Phase 1 covers the defects users hit on every visit: whole-screen spinners on refresh/tab switch/filter, a broken search clear button, a permanent 40px blank band in every reader, and misleading "damaged file" messaging for formats the app cannot read.

## Requested Change
Fix the gaps in three phases: P0 defects, P1 flow/consistency, then P2 trust, accessibility and readers. Each phase is a separate governed run.

## Reason
These problems make the app feel broken (screen flicker, dead progress UI) and erode trust: the error messages blame the user's files, the copy is contradictory, and features are advertised that cannot be used.

## In Scope (this run: Phase 1)
| ID | Gap | Location |
|---|---|---|
| UX-01 | Pull-to-refresh / Rescan replaces Home and Files with a full-screen spinner (`refreshing` counts as `isBusy`); the scan-progress banner can never render | `state_status.dart:20`, `home_view.dart:52`, `files_view.dart:75` |
| UX-02 | Files search, filter and sort each trigger a full `load()` that shows a spinner, with no debounce | `files_controller.dart:95-108` |
| UX-03 | Switching tabs reloads Home/Favorites through `loading`, flashing a spinner | `app_shell_controller.dart:71-81`, `home_controller.dart:59`, `favorites_controller.dart` |
| UX-04 | Search's clear (X) leaves the typed text in the field (no `TextEditingController`) | `search_view.dart:27-39` |
| UX-05 | All five readers reserve +40px under the app bar even when search is closed | `*_reader_view.dart` `_ReaderAppBar.preferredSize` |
| UX-06 | Indexed `.doc`/`.xls` (legacy binary) open in the DOCX/XLSX readers and show "This document may be damaged or incomplete." | `document_category.dart:16-19`, word/excel reader controllers |
| UX-26 | Reader search says "No searchable text found." when there are simply no matches | the five reader `_SearchStatusBar`s |

## Out of Scope (this run)
- UX-07 (PowerPoint): blocked on the open product question in `FEATURE-OPENREADER-P3/SRS.md` (Unresolved Question 1). The interim messaging is listed under Open Questions.
- UX-08…UX-25 and UX-27…UX-34 (later phases).
- New dependencies.
- Device and visual QA. No emulator verification is claimed unless a preview is actually run.

## Expected Behavior After Change
- A full-screen spinner appears only on the very first load. Reloads keep the existing content visible and show a thin progress indicator; Home's scan banner shows the live found-count.
- Typing in Files search is debounced (250 ms, matching the Search screen). Changing a filter or sort does not blank the list.
- Search's clear button empties the field.
- A reader's app bar height grows only while search is open.
- `.doc`/`.xls` show a "format not supported in OpenReader" message with "Open with another app" as the main action, instead of the damaged-file message.
- Reader search with zero matches says "No matches".

## Known Affected Areas
`core/presentation/utils/state_status.dart`, `core/presentation/controllers/base_controller.dart`, Home/Files/Favorites/Recents controllers and views, `app/shell/app_shell_controller.dart`, `features/search/presentation/search_view.dart`, the five reader views (and Word/Excel controllers for UX-06), `core/domain/models/document_category.dart` (read-only unless UX-06 needs it), plus existing tests in `test/widgets/document_views_test.dart` and `test/controllers/*`.

## Constraints
- Reuse existing patterns: GetX `Obx`, `StateStatus`, `CustomSnackbar`, `DocumentInteractionController.openWithExternalApp`.
- Keep the existing tests green and add regression tests per acceptance criterion.
- Don't change the database schema. No new dependencies.

## Acceptance Criteria
- **UX1-AC1:** while `refreshing`, Home and Files keep their content mounted and show the scan progress (Home) or a linear indicator. A widget test asserts that content stays visible during refresh.
- **UX1-AC2:** after an initial load succeeds, a later `load()` does not swap the content for a full-screen `LoadingView`. This covers tab select, filter, sort and search.
- **UX1-AC3:** Files search issues at most one repository query per 250 ms burst of typing. Asserted in a test with a fake clock.
- **UX1-AC4:** tapping Search's clear empties the `TextField` and resets results to the initial state. Asserted in a widget test.
- **UX1-AC5:** with search closed, each reader's app bar is `kToolbarHeight` tall; with search open, it is `kToolbarHeight + 40`.
- **UX1-AC6:** opening `.doc`/`.xls` shows the unsupported-format message plus an Open With action, and never the damaged-file text. `.docx`/`.xlsx` behaviour is unchanged.
- **UX1-AC7:** zero-match reader search shows "No matches".
- **UX1-AC8:** `flutter test` passes and `flutter analyze --no-fatal-infos` introduces no new warnings in changed files.

## Open Questions
1. **UX-07 (PowerPoint), needs a product decision:** keep PowerPoint indexed with an "Open with another app" shortcut, or hide PowerPoint from the chips and onboarding until a reader exists? This is not decided here. It remains blocked on `FEATURE-OPENREADER-P3` Unresolved Question 1.
2. **UX-06 approach:** route `.doc`/`.xls` to the unsupported-format flow (recommended), or stop indexing them? The proposal is to keep indexing them so users can still find and share those files. This needs confirmation at technical approval.

## Full gap inventory (all phases)
**P0 (Phase 1):** UX-01…UX-07 and UX-26, as above.

**P1 (Phase 2):**
- UX-08: row tap opens a sheet in Files but opens the document elsewhere.
- UX-09: two history surfaces (the Favorites>History tab and the Recents route).
- UX-10: Favorites title shows "OpenReader", and "Clear History" is visible on the Favorites tab.
- UX-11: Home's "All" chip is always selected.
- UX-12: Home lists the same five documents twice.
- UX-13: `progress` is never passed to list tiles.
- UX-14: Home's tune icon does nothing.
- UX-15: delete has no undo or destructive styling.
- UX-16: Settings "Clear Recent History" has no confirmation.
- UX-17: Files empty state has no refresh or Grant Access.
- UX-18: permanently denied permission is a dead end, with no re-check on resume.
- UX-19: PDF mode default overrides per-document choice.
- UX-20: text reader font size and wrap are not persisted.
- UX-21: text jump-to-match assumes 20px lines.
- UX-22: Word reader doesn't restore position (library limit).

**P2 (Phase 3):**
- UX-23: privacy copy contradicts All Files Access.
- UX-24: File Information placeholder rows and an unverified "verified" claim.
- UX-25: search results are not highlighted, and date formats are inconsistent.
- UX-27: Android-specific copy appears on desktop.
- UX-28: snackbars blur the screen, overlap the nav, and use generic titles.
- UX-29: bare-text empty state.
- UX-30: missing tooltips and semantics; chips don't announce selection (overlaps `FEATURE-OPENREADER-P5` ODF-P5-08).
- UX-31: fixed heights clip at large text scale.
- UX-32: fixed-width cells, no cell detail, no zoom, hard-coded orange highlight.
- UX-33: PDF has no zoom/fit, fullscreen or night mode, the thumbnail strip doesn't follow the current page, and the toolbar covers content.
- UX-34: desktop lacks keyboard shortcuts, drag-and-drop and right-click menus; phones have no "Open file".

## Status
Phase 1 (`RUN-634FD576573D433995F3E16CB7BE4B57`): **COMPLETED** 2026-10-22, scope revision 2. Release approved by the user; released as version 1.0.3+5 (local commit, not pushed).
- **Revision 0** (UX-01…06, UX-26 for Word/Excel/Text/CSV): committed as `4b9f42b` (version 1.0.2+4).
- **Revisions 1-2** (2026-10-22, committed as version 1.0.3+5):
  - PDF zero-match label from a text-layer probe.
  - Independent-review fixes F1 and F3-F6:
    - F3: no misleading empty state while scanning or on Retry.
    - F4: DB v2 prunes legacy `.doc`/`.xls` on upgrade.
    - F5: stale Search results are dropped.
    - F6: superseded Files loads are discarded.
- **Evidence:** in `features/CR-OPENREADER-UX/validation/`: `P1r1-review.md`, `P1r2-review.md`, `P1r2-qa.md`.
  - 162/162 tests pass.
  - The analyzer shows 0 errors and 2 pre-existing warnings.
  - All 9 emulator checks pass.
- **Deferred to Phase 2:**
  - F6a: Files `refresh()` isn't covered by the load-session guard, so a filter tap mid-rescan hides the refresh indicator early.
  - F6b: a rescan failure after a newer successful load replaces it with the error screen, and Retry won't rescan.
  - Home has no load-session guard.
  - Home's recents don't update on returning from a reader.
- **Not started:** UX-07 is waiting on a product decision. Phases 2 and 3 have not started.
