# CR-FILE-RELOCATE: moved files and temporary copies from other apps

## Request (user, 2026-11-23)
"also some time file got moved from place or temporary directory for those file need do something". Then: for a temporary file, "when user exit why not ask user what user want? also apply all, do better planning". Also: "there is also desktop build so keep that in mind". Go-ahead: "start" (after the plan below with its defaults).

## Today (checked in code, 2026-11-23)
- `DocumentInteractionController._verifyStillAccessible`: a missing path shows "This file may have been moved or deleted" with "Remove from Recents".
- Android `MainActivity.materialize` copies a `content://` share to `cacheDir/incoming/<hash>_<name>`; `pruneOldFiles` deletes copies older than 7 days; the OS can clear cache sooner. The original URI is not kept.
- Desktop opens files from their real paths (drop, "Open with", picker): no temporary copies.
- Schema (`app_database.dart`, version 3): `documents(id = path, path UNIQUE, ...)`, `recent_documents` and `favorite_documents` reference `documents(id)` with `ON DELETE CASCADE` and no `ON UPDATE CASCADE`. Since v3 the index holds only files the user opened or favorited (no storage scan, CR-OPENREADER-BROWSE).

## Consequences of the schema
- Relinking cannot rewrite `documents.id` in place (foreign keys are on). Relink = in one transaction: insert the new document row, move the recent and favorite rows to it (merge if the new path already has rows: keep the newer `last_opened_at`, keep a favorite if either had one), delete the old row.
- "Same name and size in the index" cannot find a moved file (the index only knows opened files). Automatic finding needs a search, which the app removed on purpose. Not part of this CR until the user decides (see Open decisions).
- Whether a document is a shared copy is derived from its path (`AppPrivatePaths.contains`), no column. One additive nullable column `documents.keep_state` (`pending`, `kept`, `saved`), schema version 4, `ALTER TABLE ADD COLUMN` only.

## Decisions (user, 2026-11-23: defaults accepted by "start")
- Exit prompt for a shared copy (Android, iOS): Keep in OpenReader / Save to device / Remove. Dismissing means Keep. Asked once per document.
- Setting "When closing a file from another app": Ask (default) / Always keep / Always remove.
- Kept copies live in app files (not the OS cache). Unreferenced copies are deleted after 7 days; total cap about 500 MB, oldest unreferenced first; a copy that had to go leaves its recent saying "temporary copy removed".
- A shared copy that is gone: say it was a temporary copy and to open it again from the other app (no Locate). A normal file that is gone: "Locate..." (picker) relinks history, favorite and reading position.
- Desktop: no exit prompt, no copy retention; gets Locate and relink.
- All in OpenReader, none in the Kit.

## Open decisions (need the user)
- Automatic finding of a moved file (the original plan's step 2) is scoped down. Options: Android MediaStore lookup by name and size; desktop search of a few likely folders (Downloads, Documents, Desktop, the old folder's parent) to a small depth. Both are new surface and the app dropped scanning on purpose. Not built until the user says which, if any.
- Save to device on Android needs the system save dialog; `file_picker`'s save flow on this plugin version is not yet verified.

## Plan (phases; each ends with tests and an emulator run)
0. Work item and schema check (this file). Done 2026-11-23.
1. Data: schema v4 (`keep_state`), relink transaction in the repositories, tests including upgrade from v3.
2. Copy lifetime: Kotlin writes to app files; pruning moves to Dart (knows the references); cap; legacy cache copies age out.
3. Missing-file handling: replace the message with Locate (normal file) or the temporary-copy message (shared copy).
4. Exit prompt, setting, Settings line with space used and Clear.
5. Verify: unit tests, emulator (content:// open, each exit choice, app killed, missing file), Windows desktop (relink, picker). iOS cannot be run here.

## Decisions changed during the work (user, 2026-11-23)
- A missing file is removed from Recents at once, with no "Remove from Recents" button. The dialog tells the user and offers Locate (not for a temporary copy); Locate restores the reading position and the favorite.
- The exit prompt is a bottom sheet (file badge, name, size; Keep in OpenReader as the main action, Save a copy, Remove, "Do this every time"), not a plain dialog. "Save a copy" keeps the copy too (keep_state `saved`), since the system save dialog returns a content URI, not a path.
- Removed Settings > About > "Show welcome screens again".
- Update cleanup: after the update is downloaded and before the swap helper starts, other installed OpenReader/OpenDocs versions are removed on desktop (user asked for removal before the new install starts). Release builds only.

## Status
2026-11-23: Phases 0-5 done and committed. Automated: 840 tests pass, 0 fail (the two Linux staging-dir tests were made portable; reader_live_sync_test's setup now waits for real loading instead of five event-loop turns).
Verified on the Android emulator: content:// open copies to files/incoming; the exit sheet appears on Back and Keep/Remove/Save paths are covered by unit tests; the Save a copy system dialog and a killed-app run were not exercised on a device.
Windows: update cleanup tested against a fake entry in the real registry (stand-in uninstaller). macOS and Linux cleanup and iOS are covered only by tests of their pure logic; they need CI or a device.
Not built (needs a decision): automatic finding of a moved file (MediaStore on Android, a bounded folder search on desktop).
The harness scripts need Python, which is not installed on this machine, so no run was registered; record the run when the harness is available.
