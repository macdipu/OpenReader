# E2 Word engine: design notes from the old engine survey (2026-10-24)

These are the ideas and lessons from surveying `lib/src/engines/docx/` (docx_creator + docx_file_viewer), under the idea-level amendment in DECISIONS.md. They are **not** code to copy.

## What the old engine gets right (ideas to keep)
- **Style resolution:** styles are resolved once at parse time, so the renderer never resolves them. The cascade is:
  1. `docDefaults`
  2. the paragraph style chain (`basedOn`)
  3. direct pPr
  4. the character style chain
  5. direct rPr
- **Containers:** `ins`, `smartTag` and `sdt` are unwrapped at block and inline level. A TOC `sdt` is recognised through `docPartGallery`.
- **Theme:** found through its relationship, with theme colour tint/shade and theme fonts.
- **Lists:** picture bullets come from `numbering.xml.rels`; bullet glyphs in the Private Use Area are handled.
- **Table styles:**
  - `tblLook` in both forms (attributes and legacy hex)
  - conditional formats: first/last row and column, banding, corners
  - `gridSpan`; `vMerge` resolved into row spans
- **Line spacing:** exact and atLeast are normalised against the font size. A hanging indent gets a spacer.
- **Embedded fonts:** deobfuscated with the font key.
- **Images:** VML `v:imagedata` is accepted as an image source. Full anchor data is captured (wrap, relativeFrom, align or offset, behindDoc).

## What the new engine must do better
- **Off the UI isolate:** parse in `Isolate.run` into a plain, sendable model. The old engine decoded, parsed and copied images all on the UI isolate.
- **Lazy rendering:** one sliver item per block, built on demand. The old engine built every widget up front inside a `Column`.
- **Search without rebuilding the document:**
  - build the search index once, from the same model the renderer uses
  - each block repaints only its own highlights
  - matches are positioned through an offset index, not a `GlobalKey` per block
  - case folding is done in a way that keeps offsets valid, since lower-casing can change the length of some Unicode text
- **Run parsing:** a run keeps all of its children in order (`w:t`, `w:br`, `w:tab`, `w:cr`, `w:noBreakHyphen`, `w:sym`). A `w:br type="page"` is a page break. The old engine dropped text when a run held a break or tab.
- **Lists:**
  - numbering state lives per `numId`/`abstractNumId` across the whole document
  - honour `w:start`, `lvlOverride`/`startOverride` and `lvlText` templates such as `%1.%2.`
  - list paragraphs keep their own paragraph formatting
- **Styles:**
  - the default paragraph style is the one marked `w:default="1"`, not a hard-coded "Normal"
  - toggle properties (b, i, caps...) XOR down the style chain
  - cycle-safe `basedOn` walks, with results memoised
- **One paragraph parser,** used for body text, table cells, headers, footers and notes alike. The old engine had a second copy for table cells.
- **Separate models:** the read model is separate from any writer. No `buildXml` methods; the read model has no write fields.
- **Errors:** typed load errors and per-part fallbacks, reported rather than swallowed. Raw exception text is never shown to the user.
- **No leaks:** gesture recognizers are owned and disposed by stateful widgets.
- **Hyperlinks:** link colour comes from the run's own style or the Hyperlink style. Internal links (`w:anchor` → bookmark) jump within the document.
- **Tracked changes:** shown deliberately, as the final view: `ins` kept, `del` dropped.

## Scope for 0.1.0 (from DECISIONS.md Q2)
- **Today's level:** runs, paragraphs, lists, tables, images (inline, and floats approximated), links, page breaks, headers and footers, search.
- **Footnotes and endnotes,** at the end of the document, with tappable references.
- **Paged print layout:**
  - real page breaks: explicit breaks, `pageBreakBefore` and section breaks
  - page size and margins from `sectPr`
  - headers and footers repeated on each page
  - layout measured with `TextPainter`, not estimated from character counts; the old engine estimated and clipped text

## Size check
Of the old core's ~43k lines, about 11-12k are for reading. The rest:
- export, ~18k, of which PDF export is 15.4k
- HTML/Markdown parsers, ~2.3k
- a builder and editor
- an unused 9k-line PDF reader

The new engine only needs the reading side.
