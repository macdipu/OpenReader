# BUG-OPENREADER-WORD-PAGEBREAK: Word reader hides text at page breaks

## Report
Found in emulator QA on 2026-10-22, on `qa-word.docx`. At the first page break, paragraph 44's text was cut off and paragraphs 45-48 were not shown at all. The user asked to fix bugs first (2026-10-23).

## Root cause (docx_file_viewer 1.0.4, `widget_generator/docx_widget_generator.dart`)
- The default `DocxPageMode.paged` paginates by *estimated* element heights for an A4 page width (`pageWidth ?? 794`, lines 178-183).
- Each page renders as a fixed-height `Container` (`pageWidth * 1.414`) with `Clip.hardEdge` and a `NeverScrollableScrollPhysics` column (lines 363-385).
- When the real wrapped height exceeds the estimate, which happens readily on phones, the overflow is clipped and the text is silently lost.

## Fix (approved in-session, 2026-10-23: "Continuous mode")
- Render Word documents in `DocxPageMode.continuous`: one scrolling column with no fixed-height pages, so nothing can be clipped.
- Search, scroll-position restore (UX-22, via `PrimaryScrollController`) and zoom are unchanged.
- Run: `RUN-1C1552C5E7F8409790571DA6E7ABA54F`.

## Release (2026-10-23)
User asked "commit with release tag": committed and tagged v1.0.8 (1.0.8+10), not pushed. Still open: the harness run never reached QA/RELEASE (PPTX run at IMPLEMENTATION with stale context; Word run at REVIEW), and device QA was not done. Close both runs (reopen/refresh as needed) and run the device checks before the next release.
