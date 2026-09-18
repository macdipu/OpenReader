# ADR-OPENDOCS-office-libraries: Word and Excel reading libraries for the Phase 3 readers

## Status
**Proposed.** Not approved. Per this project's own established process (`ADR-OPENDOCS-storage-access`, `ADR-OPENDOCS-pdf-library`), drafting this record is not approval — implementation does not start until the user explicitly approves it. Deliberately scoped to **Word and Excel only** — see Scope below for why PowerPoint is excluded.

## Context
BRD §30 Phase 3 needs DOCX, XLSX, and PPTX readers with search and reading-position restoration (§9.11–9.13, §10, §28 ODF-013…018). No Office-format library exists in this project yet.

Every candidate was verified directly against its pub.dev listing, README, dependencies, and (where relevant) publisher/maintenance metadata rather than from memory — all were published or updated after this assistant's training cutoff:

- **`docx_file_viewer` 1.0.4** (Apache-2.0): native Flutter widget rendering, no WebView, no PDF conversion. Built on a sibling package (`docx_creator`, same publisher) for DOCX parsing. Covers paragraphs, headings, lists, tables with merging, headers/footers, footnotes, inline/floating images, hyperlinks, most inline formatting, **and built-in find/highlight search with prev/next navigation** — the single feature most other candidates lack. Small but current (verified publisher, published within days of this pass, 17 likes/4.5k downloads).
- **`microsoft_viewer` 0.0.8** (MIT): the only candidate covering all three formats in one package. Its own README describes it as "a very basic package." Renders DOCX/XLSX/PPTX natively (no WebView) but with **no search at all**, and "minimum formatting" for XLSX/PPTX specifically. Low adoption (13 likes/248 downloads).
- **`in_app_file_view`** (MIT): ruled out — iOS-only, renders via `WKWebView`, depends on `dio` (networking), failing the offline-first mandate (BRD §15) regardless of licensing.
- **`power_file_viewer_v2`** (MIT): ruled out — Android rendering goes through Tencent's proprietary "TBS" WebView kernel, which requires internet to initialize and specific release-build workarounds to avoid load failures. Also stale (~3 years old, 9 likes).
- **`excel_plus` 2.22.0** (MIT): a pure-Dart, non-UI parser (fork of the original `excel` package) — reads `.xlsx` and legacy `.xls`, cell values, full styling, merged cells, multiple sheets, via a streaming (SAX) reader built explicitly for large-workbook performance. The most-adopted single candidate found in this whole pass (56 likes/16.4k weekly downloads). No viewer widget — the grid UI must be built first-party regardless of which parser is chosen, since no adequate ready-made XLSX viewer widget exists on pub.dev today (`microsoft_viewer`'s XLSX support is "minimum formatting," no search, no frozen panes).
- **`universal_file_viewer` 0.1.7** (MIT): a strong, actively-maintained multi-format viewer (42 likes, published 9 days before this pass) that renders DOCX and XLSX natively (via `excel_community`, a different `excel` fork) but **explicitly falls back to an external app for PPTX**, per its own documented notes — independent evidence that PPTX rendering isn't solved for free in the current Flutter ecosystem (see Scope below).

No paid/licensed-tier dependency (à la Syncfusion) was found necessary or preferable for Word or Excel this time — every viable candidate is MIT or Apache-2.0, so this ADR does not carry the same "product owner ruled out payment" framing `ADR-OPENDOCS-pdf-library` did. It simply didn't come up: nothing worth choosing was paid.

## Scope
**This ADR covers Word (DOCX) and Excel (XLSX) only.** PowerPoint (PPTX) is deliberately excluded: no candidate library found in this research renders PPTX with real fidelity for free (`microsoft_viewer`'s own README calls its rendering "very basic" with no search; `universal_file_viewer` — arguably the strongest multi-format candidate found — explicitly punts PPTX to an external-app fallback rather than claim inline support it can't back up). Recording a PPTX choice here would be guessing at a decision `ARCHITECTURE.md` (Unresolved Question 1) says needs to be made explicitly first: ship the basic option, build a first-party renderer, or defer PPTX with Open With as the interim path. A second ADR should follow once that product decision is made.

## Decision
**Use `docx_file_viewer` (Apache-2.0, latest `1.0.4`) for Word, and `excel_plus` (MIT, latest `2.22.0`) as the Excel parsing layer, with a first-party spreadsheet grid widget built on top of it.**

`docx_file_viewer` is chosen over `microsoft_viewer` for Word because it is the only candidate with real built-in search — ODF-014 would otherwise need to be built from scratch — while also being genuinely native (no WebView) and covering materially more of BRD §9.11's formatting list.

`excel_plus` is chosen for Excel because no adequate ready-made viewer widget exists at all (so the UI is first-party regardless of parser), and among pure parsers it is the most adopted, most actively maintained, and the only one benchmarked for the large-workbook corner cases BRD §9.12 explicitly calls out (100+ sheets, 100,000+ rows).

## Alternatives
1. **`docx_file_viewer` (chosen) for Word.** Real search, native rendering, current and Apache-2.0. Cost: small library (17 likes) relative to its feature claims — bus-factor risk, same category of tradeoff P2 already accepted for `pdfrx`.
2. **`microsoft_viewer` for Word (and, notionally, all three formats in one package).** Rejected as the primary choice for Word specifically because it has no search at all, which is a named P0 requirement (ODF-014); still worth keeping as a documented fallback if `docx_file_viewer` turns out to have a blocking defect during implementation.
3. **`excel_plus` (chosen) for Excel parsing.** Most adopted, streaming reader suited to BRD's own large-workbook corner cases. Cost: a first-party grid UI still has to be built — real work, not avoided by this choice, only unavoidable regardless of parser.
4. **Original `excel` package instead of `excel_plus`.** Same API shape, but `excel_plus`'s own published benchmarks claim materially better performance on large files, which is directly relevant to BRD's stated corner cases. Not chosen because there's no offsetting advantage to the older package found in this research.
5. **`universal_file_viewer` as a combined Word+Excel(+PPTX-fallback) dependency.** A credible, current, well-adopted package — but adopting a third party's *combined* multi-format viewer (rather than the more specialized `docx_file_viewer` for Word) would mean accepting its weaker per-format depth (no confirmed search feature was found in its documentation for any format) in exchange for one dependency instead of two. Not chosen: BRD's per-format search requirements (ODF-014/016) matter enough to prefer the more capable specialized library for Word, and Excel needs a first-party grid regardless of which parser sits under it.

## Consequences
- Word and Excel implementation can start once this ADR is approved. PowerPoint remains blocked on a separate product decision (see Scope) and, once made, a second ADR.
- The Excel reader's grid UI is a real, first-party engineering deliverable (sheet tabs, two-axis scroll, optional frozen panes, search-driven cell jump) — not a thin wrapper, unlike the Word reader which is mostly `docx_file_viewer`'s own widget.
- No new Android/iOS permission is introduced; both libraries parse/render locally, consistent with BRD §15.
- Legacy format support (`.doc`, `.xls`) is not committed by this ADR — `excel_plus` claims `.xls` reading but this is unverified beyond its README; `docx_file_viewer` documents no legacy `.doc` support at all. Tracked as `SRS.md` Unresolved Question 2, not assumed solved here.

## Risks
1. **Both libraries are small/medium projects relative to a commercial vendor** — `docx_file_viewer` especially (17 likes despite being feature-rich and very recently published). Accepted as a reasonable tradeoff for free, offline, no-licensing-gate options, matching the precedent `ADR-OPENDOCS-pdf-library` already set for `pdfrx`. Not a reason to reverse this decision without a concrete defect surfacing.
2. **Password/encrypted Office files are unverified against both libraries** — neither's documentation mentions encryption support at all. Needs a real encrypted-file test during implementation to confirm at least graceful failure (the existing generic corrupted-file error), not a crash.
3. **ZIP-container security surface** (BRD §12.5: ZIP bombs, path traversal in packaged Office files) applies to both formats and wasn't a PDF concern — neither library's ZIP-extraction code was audited in this pass.
4. **`docx_file_viewer`'s scroll-position concept for BRD's "anchor" field (§16) is unconfirmed** — if it only exposes a raw pixel/percentage scroll offset rather than a stable content anchor, restoring position after the document reflows differently on another device could land slightly off. Needs checking during implementation, not assumed.

## References
- `ARCHITECTURE.md` (Alternatives Considered, full comparison tables, ADR Recommendation)
- `SRS.md` (Unresolved Specification Questions 1–3)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P2/adr/ADR-OPENDOCS-pdf-library.md` (process precedent this ADR follows)
- pub.dev and GitHub for `docx_file_viewer`, `docx_creator`, `microsoft_viewer`, `excel_plus`, `excel`, `in_app_file_view`, `power_file_viewer_v2`, `universal_file_viewer` (versions, licenses, features, and maintenance activity verified 2026-09-18)
