# ARCH-OPENDOCS-P3: Office Readers (BRD Phase 3)

## Status
Proposed — pre-implementation. Blocked on the DOCX/XLSX library decisions and, separately, an explicit product decision on PPTX (no verified library covers it well — see Alternatives and `SRS.md` Unresolved Question 1).

## Requirements Covered
ODF-013 through ODF-018, ODF-008 (for Word/Excel/PowerPoint), ODF-P3-01 through ODF-P3-05 (see `SRS.md`).

## Existing Patterns / Components Reused
Identified before proposing anything new, confirmed against `document_category.dart` and `FEATURE-OPENDOCS-P2`'s actual implementation:
- `DocumentCategory` already has `word`, `excel`, `powerpoint` enum values (`doc`/`docx` → `word`, `xls`/`xlsx` → `excel`, `ppt`/`pptx` → `powerpoint`) — no model change needed.
- `BaseController`/`StateStatus`/`Failure`/`Either`/`runTask` — each new reader's controller extends `BaseController`, same as `PdfReaderController`.
- GetX routing/binding (`AppPages`, `Get.lazyPut`) — three new routes added the same way `AppRoutes.pdfReader`/`PdfReaderBinding` were.
- **`DocumentInteractionController` reused wholesale, again.** `toggleFavorite`, `shareDocument`, `openWithExternalApp`, `_verifyStillAccessible` are format-agnostic already; each new reader calls the same shared controller, not a reimplementation.
- `DocumentInteractionController.openDocument()` gains three more branches (`word`, `excel`, `powerpoint`), following the exact pattern the `pdf` branch established in `FEATURE-OPENDOCS-P2/TASK-010` — including that branch's own lesson: the reader owns its `markOpened()` calls, `openDocument()` must not call it for a category with a real reader, since a bare call resets the position map.
- `RecentRepository.getPosition()`/`markOpened(readingPosition:)` (added in `TASK-010`) — reused as-is, no interface change, only new map shapes per format (see `SRS.md` Data Rules).
- The "library gives primitives, OpenDocs builds the widget" pattern from P2's PDF thumbnails (`PdfDocumentViewBuilder`/`PdfPageView`) is the template for the Excel grid UI below, where no library ships a ready-made spreadsheet widget.

## Component Responsibilities (proposed)
- **`WordReaderView`/`WordReaderController`**: hosts the chosen DOCX renderer's own scrollable document widget; app bar (back/filename/search/favorite/overflow, matching `PdfReaderView`'s `_ReaderAppBar` shape); debounced scroll-position save on scroll/exit.
- **`ExcelReaderController`**: parses the workbook via the chosen parsing library into an in-memory sheet model (sheet names, cell grid); owns active-sheet index and scroll offsets; drives cell search (linear scan over parsed cell text, since no library provides this).
- **`ExcelReaderView`**: sheet-tab bar + a custom scrollable grid widget (two-axis scroll, optional frozen header row/column) built on the parsed cell model — this is first-party OpenDocs UI, not a library widget, exactly as thumbnails were for PDF.
- **`PptReaderController`/`PptReaderView`**: shape depends entirely on the Unresolved Question 1 decision — either wraps `microsoft_viewer`'s basic renderer, or (if a first-party renderer is chosen) parses slide XML into a list of positioned text/image/shape primitives and paints them with `CustomPainter`/`Stack`-positioned widgets, mirroring `PdfReaderView._horizontalLayout`'s existing custom-layout precedent. Not designed further here until that decision is made — same reasoning P2 gave for not designing a PDF-library wrapper before its own ADR was approved.
- **Password flow**: not designed here — gated on `SRS.md` Unresolved Question 3 (no candidate library's password support is verified). If Phase 3 ships without one, the existing generic corrupted-file error path handles the failure case without new UI.

## Data / Control Flow
```
DocumentInteractionController.openDocument(document)
        | (accessibility guard passes, category == word|excel|powerpoint)
        v
Get.toNamed(AppRoutes.wordReader|excelReader|pptReader, arguments: document)
        v
<Format>ReaderBinding --(document)--> <Format>ReaderController --> [format-specific parsing library]
        |                                        |
        |                                scroll/sheet/slide position
        |                                        v
        |                    RecentRepository.markOpened(id, readingPosition: {...})  (debounced + on exit)
        v
DocumentInteractionController (unchanged) <-- Favorite / Share / Open With / File Information actions
```
Identical shape to P2's flow, parameterized over three formats instead of one.

## Contracts Affected
No existing contract's signature changes. `DocumentInteractionController.openDocument()` gains three more internal branches, same as P2's single branch. New: a thin parsing-result model per format (paragraph/run list for Word, sheet/cell grid for Excel, slide/shape list for PowerPoint) — kept internal to each reader module, not shared, since the three formats have nothing structurally in common beyond "a ZIP of XML."

## Failure Handling
Same `StateStatus`/`errorMessage` UI-level pattern as every other reader — Office-specific failures (corrupted ZIP, unsupported construct, oversized workbook) are not modeled as repository failures, matching P2's PDF reasoning.

## Security Boundaries
No new Android/iOS permission — same file-access grant already covers these formats. New boundary specific to Office formats (not applicable to PDF): DOCX/XLSX/PPTX are ZIP containers, so BRD §12.5's "ZIP bomb" and "path traversal in packaged Office files" corner cases are real risks the *parsing* library's own ZIP handling must guard against, not something OpenDocs code can meaningfully add on top of a chosen library. Not audited line-by-line here (same posture P2 took for PDFium) — worth a dedicated look at each chosen library's ZIP-extraction code before shipping, given this risk doesn't exist for PDF's own container format.

## Alternatives Considered

Verified directly against each package's pub.dev listing, README, and dependency list on 2026-09-18 (not from general recollection — several of these packages were published or updated after this assistant's training cutoff).

### Word (DOCX)

| Library | License | Rendering approach | Feature coverage | Maintenance |
|---|---|---|---|---|
| **`docx_file_viewer` 1.0.4** | Apache-2.0 | Native Flutter widgets — "No WebView, no PDF conversion." Depends on a sibling package, `docx_creator` (same publisher), for the underlying `DocxReader` parsing. | Paragraphs/headings/lists/tables (with cell merging)/headers/footers/footnotes/images (inline+floating)/hyperlinks/bold/italic/underline/strikethrough/colors/fonts. **Built-in find-and-highlight search with prev/next navigation** and pinch-to-zoom — covers ODF-013/014 largely out of the box. Documented limitation: dashed/dotted borders render as solid (a Flutter rendering constraint, not a parsing gap). | Verified publisher, published within days of this scoping pass, 17 likes / 160 pub points / 4.5k downloads — small but real and current |
| `microsoft_viewer` 0.0.8 | MIT | Native, no WebView | Renders text/images/tables for DOCX with "most formatting options," per its own README. **No search.** Its own README calls the whole package "very basic." | 13 likes / 140 pub points / 248 downloads — smaller and less detailed than `docx_file_viewer` |
| ~~`in_app_file_view`~~ | MIT | **Ruled out**: iOS-only, renders via `WKWebView`, depends on `dio` (a networking library) — fails the offline-first requirement (§15) on its face, independent of formatting fidelity |
| ~~`power_file_viewer_v2`~~ | MIT | **Ruled out**: Android side uses Tencent's proprietary "TBS" WebView kernel requiring internet initialization and special release-build configuration (disabled obfuscation/shrinking) to avoid load failures; iOS uses `WKWebView`. Also stale (published ~3 years ago, 9 likes) |

**Leaning `docx_file_viewer`.** It is the only candidate with real built-in search (ODF-014) and genuinely native, offline rendering with no WebView — the other viable-on-license option (`microsoft_viewer`) is explicitly self-described as basic with no search at all.

### Excel (XLSX)

No package on pub.dev ships a ready-made spreadsheet *viewer widget* worth adopting (`microsoft_viewer`'s XLSX support is table display with "minimum formatting," no search, no frozen panes). The realistic path is a parsing library + first-party grid UI, the same shape as P2's PDF-thumbnails pattern.

| Library | License | Type | Feature coverage | Maintenance |
|---|---|---|---|---|
| **`excel_plus` 2.22.0** | MIT | Pure Dart parser, no UI | Reads `.xlsx` and legacy `.xls`; cell values (text/number/bool/date/time/formula results), full cell styling (fonts/colors/fills/borders/alignment/number formats), merged cells, multiple sheets, frozen panes *as data* (the UI still has to be built to honor them). A streaming (SAX) reader — explicitly built for large-workbook performance, directly relevant to BRD's "100,000+ rows"/"100+ sheets" corner cases. Fork of the original `excel` package, API-compatible. | Verified publisher, published within the hour of this scoping pass (active development), 56 likes / 160 pub points / 16.4k weekly downloads — the most-adopted candidate found in this whole pass |
| `excel` (original) | MIT | Pure Dart parser, no UI | The base package `excel_plus` forked from; same shape, slower/more memory on large files per `excel_plus`'s own published benchmarks | Established, but superseded in this comparison by its own fork's stated performance advantage |
| `microsoft_viewer` (XLSX portion) | MIT | Native table widget | "Minimum formatting," no search, no frozen-pane/scroll behavior described | Same small-adoption caveat as the Word comparison |

**Leaning `excel_plus` for parsing, plus a first-party grid widget** (sheet tabs, two-axis scroll, optional frozen header row/column, cell search by linear scan over parsed text) built the same way PDF thumbnails were built on `pdfrx` primitives rather than a ready-made widget. This is real, scoped engineering work — not a checkbox — flagged in Risks below.

### PowerPoint (PPTX) — the hard case

| Library | License | Rendering approach | Feature coverage | Maintenance |
|---|---|---|---|---|
| `microsoft_viewer` (PPTX portion) | MIT | Native, no WebView | Text, background image, and diagrams "with minimum formatting." No search. Package's own README: "very basic." | Same small-adoption caveat as above |
| `universal_file_viewer` 0.1.7 | MIT | Native for DOCX/XLSX; **explicitly does not render PPTX inline at all** — its own documented notes state "`.ppt/.pptx` currently use external app fallback (inline preview not yet implemented)" | None for PPTX specifically (falls through to `open_file`, which is functionally the same as this app's existing Open With action) | Verified publisher, actively maintained (9 days old at this pass), 42 likes / 150 pub points — a credible, current project, but it has made the same call this ADR is weighing: PPTX isn't solved yet |
| `dart_pptx` / `flutter_pptx` | — | **Not applicable** — these create/write PPTX files from Dart/Markdown; they have no parsing or rendering path for an existing file at all |

**No recommendation reached for PPTX in this pass.** This is a genuine, verified gap in the free Flutter ecosystem, not an oversight: the most actively-maintained multi-format viewer found in this research (`universal_file_viewer`) reached the identical conclusion and shipped an external-app fallback instead of inline rendering. See `SRS.md` Unresolved Question 1 for the three options this leaves (ship `microsoft_viewer`'s basic renderer, build a first-party OOXML slide renderer, or defer PPTX to a later slice with Open With as the interim path) — a product decision, not an engineering one, since all three are technically buildable.

## Migration / Rollback Impact
None to the database (same Data Rules reasoning as P2). Purely additive: up to three new routes/controllers/views, three new branches in `openDocument()`. Rollback is reverting whichever reader(s) shipped; nothing else depends on these existing yet (`TASK-009`'s remaining blocker — non-PDF categories still lacking a reader — is exactly what this phase would clear).

## Risks
1. **PPTX has no adequate free library** (see Alternatives) — the single largest risk in this phase, and one this document deliberately does not paper over with a recommendation it can't back up. Whichever of the three Unresolved-Question-1 paths is chosen, it should be chosen explicitly, not defaulted into.
2. **Password/encryption support is unverified for every Office candidate** (`SRS.md` Unresolved Question 3) — unlike PDF, where `pdfrx`'s `PasswordProvider` was confirmed working before the ADR was written, no equivalent confirmation exists here. A password-protected DOCX/XLSX/PPTX would most likely just fail to parse and surface the generic corrupted-file message — BRD-compliant, but not a dedicated flow, and not yet even confirmed to fail *gracefully* rather than crash (needs a real encrypted-file test during implementation, not assumed).
3. **The Excel grid is first-party UI over raw cell data**, not a library widget — real engineering (two-axis scroll, frozen panes, search-driven jump-to-cell) comparable in size to what PDF's thumbnail strip needed, but larger in scope since it's the reader's entire surface, not one supplementary feature.
4. **`docx_file_viewer` and `excel_plus` are both small-to-medium, non-corporate-backed projects** relative to, e.g., Syncfusion's commercial offerings — `docx_file_viewer` in particular has a small like/download count (17/4.5k) despite being very recently and actively published; `excel_plus` is materially more adopted (16.4k weekly downloads) and lower bus-factor risk by comparison. Accepted as a reasonable tradeoff for free, offline, no-SDK-conflict options, consistent with how P2 accepted the same tradeoff for `pdfrx` — not a reason to avoid them without a concrete problem surfacing.
5. **ZIP-container security surface** (§12.5) applies to all three formats and did not apply to PDF — not audited here (see Security Boundaries above).
6. **Large-workbook/large-table/large-deck performance** (BRD §9.11–13 Corner Cases: "100,000+ rows," "very large table," "500+ slides") is unverified against any candidate in this pass — `excel_plus`'s streaming-reader design is a good sign for XLSX specifically, but needs a real test-corpus pass during implementation, same posture P2 took for `pdfrx`.

## ADR Recommendation
Two separate decisions are ready for an ADR; one is not:
- **Word**: recommend `docx_file_viewer` — see `adr/ADR-OPENDOCS-office-libraries.md` (Proposed, not yet approved).
- **Excel**: recommend `excel_plus` (parsing) + first-party grid UI — same ADR.
- **PowerPoint**: **not ready for an ADR yet.** This needs an explicit product decision among the three Unresolved-Question-1 paths before any library commitment is recorded, the same way P2's PDF library ADR waited for the product owner's "I don't want to pay anything" instruction before Syncfusion could be definitively ruled out. Recording a PPTX library choice now would be guessing at a decision that hasn't been made.

## References
- `SRS.md` (this feature)
- `FEATURE-OPENDOCS-P2/ARCHITECTURE.md`, `FEATURE-OPENDOCS-P2/tasks/TASK-010.md` (pattern and reuse precedent)
- `lib/core/domain/models/document_category.dart` (confirmed `word`/`excel`/`powerpoint` enum values already exist)
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/core/data/repositories/recent_repository_impl.dart`
- BRD §9.11–9.13, §10, §12, §13, §14, §16, §30 (Phase 3)
- pub.dev for `docx_file_viewer`, `docx_creator`, `microsoft_viewer`, `excel_plus`, `excel`, `in_app_file_view`, `power_file_viewer_v2`, `universal_file_viewer`, `dart_pptx`/`flutter_pptx` (versions, licenses, features, and maintenance activity verified 2026-09-18)
