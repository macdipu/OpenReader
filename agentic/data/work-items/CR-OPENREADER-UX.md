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

## Phase 2 (`RUN-F6F654BCBB3742D6A8EF78225881E923`): intake 2026-10-22
Verified against HEAD `08fe4b5` by a code read; no device run.

### Scope
- UX-08…UX-22.
- Phase 1 follow-ups:
  - **F6a/F6b:** Files `refresh()` is outside the load-session guard. A rescan failure after a newer successful load replaces it with the error screen, and Retry no longer rescans.
  - **HOME-GUARD:** `HomeController.load()`/`refresh()` have no session guard. Home tab taps and deletes race a running scan.
  - **HOME-RECENTS:** `openDocument` doesn't await the reader route, so Home's Continue Reading and Recent lists stay stale after returning from a reader.

### Status at intake
- All items are still present except two:
  - **UX-19** is partly present. No per-document mode is ever stored; the global default applies on every open, and a toggle made before the settings read completes is overwritten.
  - **UX-22** is partly present. `docx_file_viewer` has no scroll API, but its scroll view inherits `PrimaryScrollController`, so position restore is feasible. Separately, horizontal table scrolls are saved as the vertical offset.
- **UX-21 constraint:** the proper fix (`scrollable_positioned_list`) would be a new dependency. Without one, the jump has to estimate wrapped line heights, using `TextPainter` measurement with the reader's font and width.

### Product decisions needed before technical approval
UX-08, UX-09, UX-10 (title), UX-12, UX-13, UX-15 (undo) and UX-19.

### Phase 2 COMPLETED (2026-10-22): v1.0.5+7
- **Release approval** recorded in-session. Run `RUN-F6F654BCBB3742D6A8EF78225881E923` is COMPLETED.
- **v1.0.5** fixes everything listed as a v1.0.4 known issue, through revisions 2-5:
  - Text/Excel/CSV close-save.
  - Bold-text jump drift.
  - PowerPoint stub refresh.
  - Onboarding latch.
  - The Excel sheet-switch offset.
  - A pre-existing blank Settings screen.
  - The "Library" navigation label.
  - Debug builds now print Flutter errors to logcat.
- **Reviews:** independent reviews covered revisions 0-3 (`P2-review.md`, `P2r1-review.md`, `P2r2-review.md`, `P2r3-review.md`). By the user's decision, revisions 4-5 were self-reviewed.
- **Checks:** 199/199 tests pass. Emulator QA passed 13/13 (`P2r4-qa.md`).
- **Tag:** local `v1.0.5`, not pushed.
- **Follow-ups:**
  - Word reader page-break clipping (`docx_file_viewer` paged layout). This is a separate bug.
  - Phase 3 (UX-23…UX-34).
  - The UX-07 product decision.

### Release (2026-10-22): v1.0.4+6, by explicit user decision
- **Released** with the revision 1 code. The user chose "Release Phase 2 now as v1.0.4" after being told about the two confirmed review issues.
- **Outside the harness gates.** The run stays BLOCKED at REVIEW with no release approval recorded, because a passing review was not faked to satisfy the gates.
- **Known issues shipped in v1.0.4** (`validation/P2r1-review.md`):
  - Jump-to-match drifts when the system Bold Text setting is on.
  - The text reader loses the last ~2s of scrolling on close.
  - Excel/CSV can overwrite the saved position with 0 on close.
  - (Plausible) The PowerPoint stub doesn't refresh Home; onboarding flickers on resume.
- **Not verified on the emulator before release:** UX-22 Word restore, UX-19/13 PDF mode and progress, UX-09/10 Library, UX-16 Settings confirm, UX-18 resume.
- **Tag:** local `v1.0.4`, not pushed. Pushing it runs `.github/workflows/release.yml`.

### Status history (2026-10-22): paused at REVIEW before v1.0.4 (superseded)
- **Revision 1** is implemented in the uncommitted working tree on top of `08fe4b5`.
  - 192/192 tests pass.
  - The analyzer shows 0 errors and 1 pre-existing warning.
- **The second independent review** (`validation/P2r1-review.md`) found:
  - 2 confirmed issues: bold-text measurement, and the reader close-save happening after the scroll view detaches (a pre-existing bug, reproduced on the emulator);
  - 2 plausible issues: the PowerPoint stub refresh, and the onboarding flicker.
  - Proposed fixes for all four, as revision 2, were offered; the user chose "Stop here".
- **To resume:**
  - Decide on revision 2.
  - Reopen the run (this voids the technical approval), fix, re-review.
  - Finish emulator QA: UX-22, UX-19/13, UX-09/10, UX-16, UX-18.
  - Release approval and the commit.

### Product decisions (user, in-session, 2026-10-22)
- **UX-08:** a row tap opens the reader on every screen. The actions stay in the ⋮ menu, and the Files action sheet moves to long-press.
- **UX-09/UX-10:** keep the History tab and delete the Recents route.
  - "See All" switches to the Favorites tab with History selected.
  - The tab is titled "Library".
  - Clear History shows only on the History tab.
- **UX-12/UX-13:** split Home's recents.
  - Continue Reading shows the 1-3 most recent documents, with a progress bar for PDFs (page/pages). Other formats get no bar.
  - The Recent rows show the next documents, with no duplicates.
- **UX-15:** no undo; delete stays permanent with "cannot be undone". Add destructive styling.
- **UX-19:** the PDF view mode is remembered per document. The Settings default applies only to PDFs that were never toggled.

### Obvious-default items
These have a clear fix, but the design still goes through technical approval:
- UX-11: Home chips are not shown as selected.
- UX-14: remove the dead tune icon.
- UX-15: destructive styling for delete.
- UX-16: confirm before Clear Recent History.
- UX-17: Files empty and no-access states get actions.
- UX-18: an Open Settings fallback, plus a re-check on resume.
- UX-20: persist text reader font and wrap globally.
- UX-22: restore the Word reader's position.
- F6a/F6b, HOME-GUARD, HOME-RECENTS.

## Phase 3 (`RUN-1553CD5CD2D048B3931641A98B32908F`): intake 2026-10-22
Verified against `v1.0.5` by a read-only code sweep; no device run.

### Scope and status
- UX-23, UX-24, UX-25 and UX-27…UX-34 are all still present. UX-28 is partly present: some call sites already pass the document name as the title.
- UX-26 was done in Phase 1.

### Key findings
- **UX-23 (priority).** The privacy copy contradicts the decided Play Store special-access declaration (ODF-P5-02 / ADR-OPENREADER-storage-access mitigations 1 and 3):
  - Settings says "Scoped storage sandbox … No broader filesystem access".
  - The "SANDBOXED" pills (Settings, Library, Files Info) and File Information say "sandboxed storage scope".
  - `docs/privacy.html` is stale: Android-only, "documents you open", generic permission wording, and Firebase Cloud Messaging, which was removed.
- **UX-30/UX-31 are ODF-P5-08 (accessibility).** The decided approach:
  - Flutter `Semantics` only, plus tooltips, with no third-party package.
  - Additive changes only.
  - Verified with `flutter test` semantics matchers.
- **UX-34 drag-and-drop** needs a new dependency (`desktop_drop` or `super_drag_and_drop`), which conflicts with the phase-wide "no new dependency, no ADR" rule.
- **Side note:** onboarding lists PowerPoint as supported, but UX-07 is still undecided.

### Phase 3 COMPLETED (2026-10-22): v1.0.6+8
- **Run:** `RUN-1553CD5CD2D048B3931641A98B32908F` is COMPLETED, with release approval recorded in-session.
- **Shipped:** all 11 items (UX-23…UX-34), plus revision 1 fixes from the independent review (`validation/P3-review.md`).
- **New dependency:** `desktop_drop`, per `adr/ADR-OPENREADER-desktop-drop.md`.
- **Checks:**
  - 220/220 tests pass, and the analyzer shows 0 errors.
  - Android emulator QA passed 8/8 (`validation/P3-qa.md`).
  - The macOS build compiles and launches. Desktop interactions are verified by widget tests only; screen capture wasn't available.
- **Tag:** local `v1.0.6`, not pushed.
- **Logged follow-ups:**
  - Android 15+ may ignore immersive fullscreen.
  - The grid zoom pill can cover the last cells.
  - A drop while a reader is open opens on top.
  - Unused network-capable packages remain in `pubspec`.
  - Word page-break clipping.
  - The UX-07 decision.

### Product decisions (user, in-session, 2026-10-22)
- **UX-23:** the pills say "OFFLINE". The Settings and File Information copy is rewritten to name All Files Access and the full-device index, and to say nothing is uploaded. `privacy.html` is updated, including removing Firebase.
- **UX-24:** the two placeholder rows are hidden. The badge becomes "Read on-device — OpenReader makes no network calls", with no "verified".
- **UX-25:** absolute dates are locale-aware (`DateFormat.yMMMd`, e.g. "Oct 22, 2026"); history keeps relative times. Search and Files highlight matches.
- **UX-27:** desktop gets a welcome variant without the permission paragraph and with a single "Get started" button. Other Android-only copy becomes platform-neutral.
- **UX-28:** snackbars keep the GetX style but drop the blur and dim, sit above the bottom nav, and show a title only when it's meaningful.
- **UX-32:** tapping a cell shows its full value with Copy; −/+ zoom buttons; theme-coloured highlights, with all matches lightly marked.
- **UX-33:** zoom and fit-width buttons; the thumbnail strip follows the current page and the toolbar no longer covers content; fullscreen; a night-mode toggle.
- **UX-34:** a phone "Open file" item in Home's ⋮ menu; Ctrl/Cmd+O, Ctrl/Cmd+F and Esc shortcuts; right-click row menus; drag-and-drop with a **new dependency**, which needs an ADR and technical approval.

### Product decisions needed
- UX-23: pill wording.
- UX-24: the File Information placeholder rows.
- UX-25: the date format.
- UX-27: desktop onboarding.
- UX-28: snackbar style.
- UX-32: grid zoom.
- UX-33: whether fullscreen and night mode are in scope.
- UX-34: where the phone "Open file" entry goes, and drag-and-drop with its dependency.

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
