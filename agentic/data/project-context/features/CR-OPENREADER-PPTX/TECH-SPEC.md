# CR-OPENREADER-PPTX: technical spec

Status: APPROVED (in-session design choice, 2026-10-23). Base `fe54bd0` (v1.0.7).

## Design
- **`PptxParser`** (`services/utilities/pptx_parser.dart`) is pure Dart, using `archive` and `xml`.
  - The ZIP is guarded by the existing `ZipSafetyGuard`.
  - **Slide order:** `ppt/presentation.xml` `p:sldIdLst`, mapped to slide parts via `ppt/_rels/presentation.xml.rels`.
  - **Per slide**, in document order:
    - text shapes (`p:sp` / `p:txBody`) give paragraphs, with the bullet level from `a:pPr@lvl`;
    - the title comes from the `title`/`ctrTitle` placeholder;
    - tables (`a:tbl`) give rows of cell text;
    - pictures (`p:pic`) are resolved through the slide's rels to `ppt/media` bytes, keeping only PNG, JPEG, GIF, BMP and WebP.
  - A slide with nothing renders as an empty slide.
  - Output: `PptxPresentation(slides: [PptxSlide(title, blocks)])`. Blocks are paragraph, table or image.
- **`PowerPointReaderController`** works like the other readers:
  - It parses in `Isolate.run`.
  - It tracks the current slide (a `PageView`).
  - **Search** is over slide text, giving matching slide indices with previous/next and "No matches".
  - **Position:** saved as `{slide_index, slide_count}` (debounced, and on close via `readerClosedAfter`) and restored on open. Home's progress bar now covers PowerPoint as well as PDF.
  - **Errors:** too large or damaged files show the BRD §13 error messages.
  - **Favorite, share and open-with** go through `DocumentInteractionController`.
- **`PowerPointReaderView`:**
  - The app bar has search, star, and ⋮ (Share, Open With).
  - A `PageView` shows slide cards, each scrollable.
  - The bottom bar has previous, "3 / 12" and next.
  - Shortcuts: Ctrl/Cmd+F, Esc, and Left/Right arrows. All buttons have tooltips.
- **Wiring:**
  - New `AppRoutes.powerpointReader`, with a page and binding.
  - `openDocument` routes PowerPoint to the reader; the "not part of this build" stub is removed.
  - The incoming resolver accepts `.pptx`. The pptx MIME type is added to the resolver map and the Android intent filters.
  - `.ppt` is removed from `DocumentCategory` (unsupported, like `.doc`/`.xls`).
  - Onboarding lists PowerPoint again.

## Tests
- **Parser**, on a synthetic `.pptx` built in the test: order, title, bullets and levels, a table, an image, an unsupported image skipped, and a damaged or non-zip file.
- **Controller:** load, navigation, search, position save and restore, progress.
- **View:** shows "Slide 1 of N" and navigates.
- **Category:** `.ppt` maps to unknown and `.pptx` to PowerPoint; the resolver accepts `.pptx`.
