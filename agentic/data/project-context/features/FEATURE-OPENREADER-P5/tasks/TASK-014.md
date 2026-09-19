# Engineering Task

## Status
DONE (implemented, verified live on a real emulator, `flutter analyze`/`flutter test` verified) — 2026-09-19. Follow-on to TASK-013: after the splash-hang fix unblocked booting, the user asked to manually walk every implemented feature on the emulator ("check all features development till now, they all worked"). This surfaced two real, previously-undetected bugs — both fixed and re-verified in this task.

## Story
First real end-to-end manual QA pass across every shipped reader and shell screen (BRD Phases 1-4), on the same emulator TASK-013 first got booting.

## Setup
No usable real-world sample files existed for TXT/CSV/XLSX (only PDF/DOCX samples from earlier ad-hoc testing were present on the emulator's `/sdcard/Download`). Generated a real `.xlsx` fixture using the project's own `excel_plus` dependency (`Excel.createExcel()` + `.encode()`, run via a throwaway `flutter test` file, deleted after) and hand-wrote `.txt`/`.csv` fixtures (the CSV deliberately includes BRD's named hard corner cases: a quoted comma and a multi-line quoted field). Pushed all three plus the existing PDF/DOCX samples via `adb push`, then granted storage access via `adb shell appops set ... MANAGE_EXTERNAL_STORAGE allow` (this session's `emulator-5554` doesn't have a working Play Store/Files UI to grant it interactively) and ran "Refresh file index" from Settings.

## Findings

### Bug 1 (severe, fixed): every `.csv` file failed to open
**Symptom:** opening any CSV showed "This document may be damaged or incomplete." — 100% reproducible, not content-dependent.

**Root cause, confirmed via a temporary `debugPrint` in the catch block:** `CsvReaderController._load()` (`lib/features/csv_reader/presentation/csv_reader_controller.dart`) wrapped parsing in `Isolate.run(() => xls.Excel.fromCsv(csvText))`. The resulting `Excel`/`Sheet` object graph is not isolate-sendable — `Isolate.run` threw `Invalid argument(s): Illegal argument in isolate message: object is unsendable - Library:'dart:async' Class: _AsyncCompleter`. The controller's own doc comment had assumed this was safe because `Excel.decodeBytesAsync` (the `.xlsx` path) uses the same `Isolate.run` mechanism successfully — but reading `excel_plus`'s source (`lib/src/platform/isolate_io.dart`) shows `decodeBytesAsync` calls the exact same `Isolate.run`, just against a different factory (`Excel.decodeBytes`) that happens to produce a sendable result. Sendability depends on what the factory builds, not on which entry point is used; that assumption was never actually verified before, and this environment's first real CSV open exercise (never done in any prior phase, since no emulator existed) is what caught it.

**Fix:** parse synchronously on the calling isolate instead (`final workbook = xls.Excel.fromCsv(csvText);`, no `Isolate.run`). Removed the now-unused `dart:isolate` import. This reintroduces `ARCHITECTURE.md` Risk 2 (no UI-thread offload for a large CSV) — the 20MB `maxBytes` ceiling is the only remaining guard; a real isolate-safe fix (e.g. parsing to plain sendable data structures inside the isolate rather than returning `Excel` objects) is deferred, not attempted here, since it would touch the shared `CellGridController` interface non-trivially.

**Verified:** the hand-written CSV fixture opens correctly, renders the grid including the multi-line quoted cell, after the fix.

### Bug 2 (moderate, fixed): Favorites tab doesn't reliably reflect favorites toggled elsewhere
**Symptom:** favoriting a document from a reader or Files' context menu updates the database correctly (confirmed directly via `sqlite3` against a pulled copy of `openreader.db`) and updates that same screen's own heart icon correctly, but the Favorites tab can keep showing a stale list — sometimes indefinitely, for the rest of the session.

**Root cause:** `DocumentInteractionController` (`lib/core/presentation/controllers/document_interaction_controller.dart`) — documented as "the single reactive source of truth ... shared by Home, Files, Search, Recents, and Favorites" — was registered with `Get.lazyPut(..., fenix: true)` in `AppShellBinding`. `fenix: true` allows GetX to dispose the instance and lazily recreate a fresh one on next access. `FavoritesController.onInit()` (`lib/features/favorites/presentation/favorites_controller.dart`) subscribes exactly once, at construction, via `ever(Get.find<DocumentInteractionController>().favoriteIds, (_) => load())`. If the underlying controller is ever recreated, that subscription is left watching a dead, orphaned Rx object — toggles made through the new instance never reach it again, for the lifetime of that `FavoritesController` (which is itself long-lived across tab switches, since GetX keeps it alive as part of the bottom-nav shell).

**Fix, two parts:**
1. `AppShellBinding`: `DocumentInteractionController` now registered via eager `Get.put(..., permanent: true)` instead of `Get.lazyPut(..., fenix: true)` — one stable instance for the whole app lifetime, matching what its own doc comment already promised. (`Get.lazyPut` has no `permanent` parameter in this GetX version, `4.7.3` — only `fenix` — hence the switch to `Get.put`.)
2. `AppShellController.changeTab()`: also explicitly calls `Get.find<FavoritesController>().load()` whenever switching to the Favorites tab, as a belt-and-suspenders reload independent of the `ever()` subscription's health. Small, always-correct, and was still necessary even after fix (1) alone in testing — the exact reason the `ever()` chain still missed an update after (1) wasn't isolated further (some other subtlety in this GetX version's `ever()`-on-`RxSet`-mutation semantics), but reloading on tab-select is a legitimate independent hardening regardless of the exact remaining cause, not a wallpapered symptom fix.

**Verified:** toggled favorites on two different documents from two different screens (a reader's heart icon, and Files' context menu), confirmed both persist in `favorite_documents` via direct `sqlite3` inspection, and confirmed the Favorites tab shows both, including a fresh cold-app-launch case and a live cross-screen toggle case (switch away, toggle a favorite elsewhere, switch back to Favorites — updates every time now).

## Minor finding, not fixed (low priority, not reproduced cleanly enough to root-cause)
A duplicate-looking `qa-sample.csv` entry appeared in "All Files"/Search at one point, pointing to a private app-cache path (`/data/user/0/com.onkur.customer/cache/qa-sample.csv`) rather than the real file (`/storage/emulated/0/Download/qa-sample.csv`) — both indexed as separate `documents` rows. Best guess: `receive_sharing_intent`'s native side (wired via `IncomingIntentService`, TASK-009) copied the file into cache and re-indexed it, though no real Android share/send intent was deliberately sent to the app during this session, so the trigger wasn't conclusively identified. Cosmetic only (the cache-path entry fails to open, same as any moved/deleted file would, per BRD §13's existing guard) — not chased further given the CSV/Favorites bugs were higher-value. Flagged here for whoever picks up ODF-P5-05 (offline/network audit) or a future TASK-009 hardening pass to investigate if it recurs.

## Full manual verification matrix (this session, real emulator)
| Area | Result |
|---|---|
| Home (category counts, Continue Reading) | Correct (PDF 10, Word 7, Excel 1 real scan; recents list correct) |
| All Files (list, category filter chips, metadata) | Correct |
| Search (by filename) | Correct ("4 result(s)" for a real query) |
| Favorites (toggle, cross-screen sync, persistence) | Bug found and fixed (see above) |
| Settings (theme radio, Refresh file index, Clear Recent history, Clear cache) | Refresh file index exercised and correct; others not individually exercised this pass |
| PDF reader (render, scroll, page counter, search-and-jump) | Correct |
| Word reader (render, pagination, styling) | Correct |
| Excel reader (grid render) | Correct |
| CSV reader | Bug found and fixed (see above); grid render correct after fix, including multi-line quoted cell |
| Text reader (render) | Correct |
| Share / File Information / Open With (menu presence) | Menu items present and correctly labeled; not exercised further (no target app for Open With, no share-sheet verification, in this emulator) |
| PowerPoint reader | N/A — no reader exists yet, blocked on the still-open product decision (`FEATURE-OPENREADER-P3/SRS.md` Unresolved Question 1); not a bug |
| Open From Other Apps (TASK-009 real intent delivery) | Not exercised this pass |

## References
- `TASK-013.md` (the splash-hang fix this QA pass built on)
- `lib/features/csv_reader/presentation/csv_reader_controller.dart`, `lib/app/shell/app_shell_binding.dart`, `lib/app/shell/app_shell_controller.dart`, `lib/features/favorites/presentation/favorites_controller.dart`

## Out of Scope
- A real isolate-safe fix for CSV parsing (offloading to a background isolate without the sendability crash) — deferred, documented in the code comment.
- Root-causing exactly why the `ever()` subscription alone (fix part 1) still wasn't sufficient without the explicit tab-select reload (fix part 2).
- The stray cache-path duplicate document entry (see Minor finding above).
- Settings' "Clear Recent history"/"Clear cache" actions, Share/Open With's actual external-app handoff, and TASK-009's real intent delivery — not exercised this pass.
