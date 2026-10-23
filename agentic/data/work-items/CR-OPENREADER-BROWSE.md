# CR-OPENREADER-BROWSE: in-app browsing instead of storage scanning; drop privacy badges

## Request (user, 2026-10-23)
1. "I don't want anything called sandboxed or local only. Remove all, no need to mention anything about private or sandbox."
2. "In-app scan remove from all OS, and give in-app browse for all."

## Routing
- **Work type:** `change_request` (brownfield).
- **Run:** `RUN-5C655F87FED64C228D06F74893C66CAA`. It was started for item 1; the scope was widened to item 2 at intake.
- **Planning:** NO_REPLAN.

## Decisions (user, in-session, 2026-10-23)
- **Copy:** remove every sandbox, local-only, offline and private badge and claim from the app. That covers:
  - the pills and the Settings privacy banner and section;
  - the Library and Files footers, and File Information's diagnostic;
  - onboarding's "100% OFFLINE" and "Private & Offline" wording, and the splash tagline;
  - "Rescan Local Storage", which becomes "Rescan Storage".
  - **Kept:** the Android All Files Access disclosure (Play policy) and `docs/privacy.html` (the legal policy page).
- **Browse:** remove scanning on every platform; every platform gets an in-app folder browser. Approved design (Approve, Recommended):
  - **Scanning:** no auto-scan, no Rescan, no scan progress, no indexed counts.
  - **The Files tab becomes "Browse":**
    - Starts at device storage. Android: Internal storage plus SD cards. Desktop: Home, Documents, Downloads, Desktop.
    - Shows folders and supported documents, with a breadcrumb, back/up, sort, and a format filter for the current folder.
    - Opening a document works as before: the reader, recents, favorites, and the ⋮ actions.
  - **Home:** Continue Reading and Recent stay. The format-count chips and "N files indexed" are removed, and a "Browse files" button replaces them.
  - **Android** keeps All Files Access, which is needed to browse any folder. Onboarding says it's for browsing.
  - **Upgrade cleanup:** old index entries you never opened or favorited are removed.
  - **Unchanged:** Open file, drag-and-drop and the shortcuts.
- **Search:** "Both". Instant results from documents you've opened, plus "Search on device", which searches the browsed folder and its subfolders on demand, with progress and cancel.

## Status
**COMPLETED** 2026-10-23, released as **v1.0.7+9**. Release approval was recorded in-session. The local tag `v1.0.7` has not been pushed.
- **Review:** an independent review found 5 confirmed issues, all fixed in revision 1 (`validation/review.md`).
- **Checks:** 209/209 tests pass, and the analyzer shows 0 errors.
- **QA:** partial on the Android emulator (`validation/qa.md`). Opening documents from Browse, subfolder search and the revision 1 fixes are verified by tests only.
- **Also fixed:** `indexDocument` used INSERT OR REPLACE, which deleted favorites and reading positions on re-index. It now inserts or updates.
