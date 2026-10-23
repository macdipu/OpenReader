# CR-OPENREADER-BROWSE: independent review (2026-10-23)

The reviewer was an independent subagent working read-only. The analyzer showed 0 errors.

## Confirmed
1. Browse's `PopScope` (in the shell's `IndexedStack`) handles back on every tab, so back on Home moves Browse up a folder instead of exiting.
2. Desktop "search all storage" walks Documents, Downloads and Desktop twice (they're inside the Home root), so matches appear twice.
3. "Search on device": GetX `Get.back()` only closes an open snackbar and doesn't pop, so the Search screen can stay open.
4. `searchSubfolders`'s future never completes once cancelled. This is harmless today because every caller uses `unawaited`.
5. With nested desktop roots (Home, then Documents), the breadcrumb drops Home and `goUp` jumps to the roots list.

## Plausible
- The search field text and `filter` drift apart across folder changes and the search-results view.
- `openFromBrowse` ignores a failed index write.
- Search walks huge system trees (macOS `~/Library`, Windows `AppData`, Android `data`/`obb`), and the 500 cap is per root.
- Symlinks (`Link`) are dropped from listings.
- One leftover "scans" string in File Information; stale doc comments.

## No issue found
- Load-session races and Rx tracking.
- Delete.
- The `indexDocument` upsert and the incoming-intent resolver.
- DB v3 SQL and migration order.
- No leftover references to removed members; Home pull-to-refresh.
- The macOS home folder; Android roots.

## Outcome
The user approved fixing all of these and releasing 1.0.7 (revision 1).
