# CR-OPENREADER-UX Phase 1, revision 2: emulator QA (2026-10-22)

- **Device:** Android emulator `Pixel_4a` (1080x2340).
- **Build:** debug APK of the revision 2 working tree on top of `4b9f42b`, version 1.0.2.
- **Storage access:** All Files Access was granted with `appops`.
- **Fixtures:** pushed to `/sdcard/Download`:
  - `qa-text.pdf` (has a text layer)
  - `qa-scanned.pdf` (a filled rectangle, no text)
  - `qa-word.docx` (119 paragraphs)
  - `qa-notes.txt`
  - `qa-legacy.doc` and `qa-legacy.xls` (OLE2 headers)
- **Screenshots:** in `qa-p1r2/`.

| Check | Result | Evidence |
|---|---|---|
| UX-06: `.doc`/`.xls` not indexed | PASS. Files shows 9 docs; Excel 0, Word 2 (both `.docx`); no `qa-legacy.*` | `04-files.png` |
| UX-05: reader app bar compact when not searching | PASS for PDF and Word. The 40px bar appears only while searching and collapses on close | `06`, `07`, `16`, `18`, `23` |
| UX-05: PDF/Word state kept across the search toggle | PASS. The PDF page didn't reload. The Word viewer stayed at paragraph 6 through open, search and close | `18`, `21`, `22`, `23` |
| UX-26/F1: scanned PDF zero-match | PASS. "No searchable text found." | `07-scanned-search.png` |
| UX-26/F1: text PDF zero-match | PASS. "No matches" | `14-text-nomatch.png` |
| PDF match | PASS. "1 of 1 result(s)", with the match highlighted | `15-text-match.png` |
| UX-26: Word zero-match | PASS. "No matches" | `22-word-zebra.png` |
| UX-04: Search clear | PASS. The field emptied and the screen returned to its initial state | `12-search-cleared.png` |
| UX-01: Home pull-to-refresh | PASS. Content stayed mounted with only the refresh indicator; no full-screen spinner | `27`, `28` |

## Not verified on device
These are covered by unit/widget tests only:
- **Scan progress banner.** The emulator's scan finished too fast to capture.
- **F3** (first-run empty-state hiding, Retry spinner).
- **F4** (v1→v2 upgrade). This was a fresh install, not an upgrade; the migration is tested against real SQLite via ffi.
- **F5/F6** (races).

## Observations (not Phase 1 defects)
- Home's Continue Reading and Recent lists don't update on returning from a reader; they update on the next pull or tab reload. This is existing behaviour.
- On the Search screen, the "Search documents by filename." hint sits tight under the field.
