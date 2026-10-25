# CR-LEGACY-OFFICE: legacy binary .xls, .doc and .ppt in universal_document_viewer

## Status
**Backlog (coming soon).** Not started, no run, no technical plan approved. Listed as "Coming soon" in the package README (package commit 63ddce2).

## Request (user, 2026-10-25)
"How do I give support to those: Legacy binary .doc, .xls and .ppt files are not supported", then "add these in future task coming soon".

## Proposed approach (not approved)
The package's own Dart engines, like the existing formats: no server conversion, no platform preview.
All three formats are Compound File Binary (CFB/OLE2) containers with record streams, documented by Microsoft ([MS-CFB], [MS-XLS], [MS-DOC], [MS-PPT]).

Each phase maps the file onto the existing models, so the viewers, search, thumbnails and positions work unchanged. Each ships on its own, and its format becomes "supported" only when that phase is done.

0. **CFB reader and safety guard:** directory, FAT/mini-FAT and streams. It refuses sector-chain loops, out-of-range sectors and oversized streams, like `ZipSafetyGuard`.
1. **.xls (BIFF8):** shared strings, cells (LABELSST, NUMBER, RK/MULRK, BOOLERR, cached FORMULA results), XF/FONT/FORMAT, BOUNDSHEET, MERGEDCELLS, COLINFO/ROW. Mapped onto the `SpreadsheetController` model.
2. **.doc:** FIB, then the piece table (CLX) for text and paragraphs. After that, CHPX/PAPX and the stylesheet for formatting, lists and tables. Mapped onto `WordDocument`.
3. **.ppt:** the record tree (SlideListWithText, TextCharsAtom/TextBytesAtom) and the Pictures stream. Mapped onto the slide model, as text-only slides.

Out of scope: encrypted legacy files (they report `passwordRequired`), macros and embedded OLE objects.

## Open questions (for the technical plan)
- Test files: generated (LibreOffice can save these formats) or real-world samples, and their licences.
- Release order and version numbers (proposed 0.2.0 / 0.3.0 / 0.4.0).
- When the OpenReader app should turn on `.xls`, `.doc` and `.ppt` (file filters, intents).

## Next step
When the user schedules it: run intake, then write the technical plan for phases 0 and 1 and get the user's approval before any code.
