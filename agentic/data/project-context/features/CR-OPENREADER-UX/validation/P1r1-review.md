# CR-OPENREADER-UX Phase 1, revision 1: independent review (2026-10-22)

The reviewer was an independent subagent that saw the code only, not the implementer's conclusions. It read `4b9f42b` (revision 0) and the uncommitted revision 1 diff, and checked them against the pdfrx 2.4.8 / pdfrx_engine 0.4.7 and docx_file_viewer 1.0.4 sources.

## Revision 1 (PDF text-layer probe)
- **F1, medium, confirmed by the implementer in `pdf_text_formatter.dart:49-51`.** For a page that isn't loaded yet, `PdfTextSearcher.loadText` returns `PdfPageText(fullText: '')` and caches it; it does not return null. A text PDF searched during progressive loading could therefore be probed as "scanned" and keep "No searchable text found." for the rest of the session.
  - **Fixed in the working tree.** The probe now reads raw `PdfPage.loadText()` through `useDocument`, which returns null for an unloaded page and so leaves `hasTextLayer` unknown. 156/156 tests pass, and the analyzer is unchanged.
  - This change came after review, so it needs a run reopen.
- **F2, low.** A scanned PDF briefly shows "No matches" before the async probe settles. This was accepted in the approved design.
- **No issues found:** listener timing against the searcher's notify sequence, Obx tracking of `hasTextLayer`, and behavior after close.

## Revision 0 (`4b9f42b`)
- **F3, low-medium.** During the first-run auto-scan, and on Retry from an error with nothing loaded, Home (and Files after an error) shows the "No documents found / Pull down to scan" empty state under the scan banner, where it used to show a spinner.
- **F4, low-medium.** There is no DB migration for upgrades. Existing `.doc`/`.xls` rows keep the `word`/`excel` category until a manual rescan prunes them; until then, opening one shows the "damaged" error.
- **F5, low, pre-existing race.** Search `clear()` doesn't cancel a search already in flight, so stale results can appear under the empty field.
- **F6, low, plausible, now more visible.** Files `load()` has no session guard, so an older, slower load can overwrite the results of a newer filter.
- **No issues found:**
  - PDF/Word viewer state across the search toggle (no reload).
  - Files debounce lifecycle.
  - Search clear ownership.
  - Manifest/MIME consistency.
  - The "No matches" labels.
