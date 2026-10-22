# CR-OPENREADER-UX Phase 1, revision 2: independent re-review (2026-10-22)

The reviewer was a fresh independent subagent working read-only. It reviewed the revision 2 working-tree diff on top of `4b9f42b` and checked it against the pdfrx 2.4.8 / pdfrx_engine 0.4.7 and sqflite_common sources. It also ran the repository and PDF helper tests: 25/25 pass.

## Result: no bugs in items 1-4
- **PDF probe (F1 fix).**
  - `useDocument(ensureLoaded: true)` opens the document only; it doesn't load pages.
  - Raw `loadText()` returns null for unloaded pages (`pdfrx_pdfium.dart:1715`), so the null branch is live, and a later re-probe can resolve once the viewer has progressively loaded more pages.
  - The probe is safe to run alongside the searcher, because both go through the same BackgroundWorker.
  - The probe fires only on the searcher's final notify.
- **F3.** The `isScanning` read is tracked by the Obx. Both paths are tested.
- **F4.** Confirmed: `onConfigure` (`foreign_keys = ON`) runs before the upgrade transaction (`database_mixin.dart:1124` vs `:1134/1151`), so the cascade fires. The extension format matches what the scanner stores. The upgrade test really reopens the database at v1.
- **F5.** The stale result is dropped, and the status stays `initial`.

## Item 5 (F6): two low edge cases, deferred to Phase 2
Neither leaves a screen stuck: the newest `load()` always reaches a terminal status.
- **F6a.** `FilesController.refresh()` doesn't bump `_loadSession`. A filter tap during a rescan can finish first and hide the refresh indicator mid-scan, and a `load()` started just before `refresh()` can briefly show pre-scan data.
- **F6b.** If the rescan fails after a newer `load()` succeeded, `handleFailure` replaces fresh results with the error screen. That `load()` also reset `_retryScan`, so Retry won't rescan.

## Noted, out of scope
`HomeController.load()` has no session guard. This predates this run.

## Gaps
The PDF `_onSearchProgress` wiring and the `.fullText` mapping have no unit tests, because there is no PDFium in tests. They are covered by emulator QA.
