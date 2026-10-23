# CR-OPENREADER-PPTX: in-app PowerPoint (.pptx) slide viewer

## Request (user, 2026-10-23)
"Also fix PowerPoint". This resolves UX-07 and `FEATURE-OPENREADER-P3` SRS Unresolved Question 1.

## Decision (user, in-session, 2026-10-23: "In-app slide viewer (Recommended)")
- **What the reader shows:** a new PowerPoint reader for `.pptx`, slide by slide. Each slide shows its text (titles, bullets, tables as text) and its pictures.
- **Features:**
  - a slide counter;
  - search;
  - reading position;
  - favorites;
  - "Open with another app" stays in the menu.
- **Limits:** it is not a pixel-faithful layout; there are no animations or exact positioning.
- **No new dependency.**
- **Old binary `.ppt`** stays unsupported, like `.doc`/`.xls`.

## Run
`RUN-AAA30CA942244146BB6BD97A1119DDBD`. Spec: `features/CR-OPENREADER-PPTX/TECH-SPEC.md`.

## Implementation (2026-10-23)

- `lib/services/utilities/pptx_parser.dart`: slide order from `p:sldIdLst`; title from the `title`/`ctrTitle` placeholder; body paragraphs keep `a:pPr@lvl`; `a:tbl` → rows of cell text; `p:pic` → slide rels → `ppt/media` (png/jpg/gif/bmp/webp only); group shapes walked; UTF-8 decoding.
- `lib/features/powerpoint_reader/` (binding, controller, view): `ZipSafetyGuard` before parse, parse in `Isolate.run`, PageView + "n / N" bar, Left/Right keys, search across slides (prev/next, "No matches"), position `{slide_index, slide_count}` (2 s debounce + on close), BRD §13 errors, empty-deck message.
- Wiring: `AppRoutes.powerpointReader`; `openDocument` routes PowerPoint (stub removed; unknown → "This file type is not supported."); resolver accepts .pptx + its MIME; manifest VIEW/SEND filters gain the .pptx MIME; `'ppt'` removed from `DocumentCategory`; onboarding lists PowerPoint; History progress for slides.
- Tests: `test/services/pptx_parser_test.dart` (7), `test/controllers/powerpoint_reader_controller_test.dart`, updated interaction/resolver/onboarding tests.

Status: implemented; full suite green (218 + 11 tests). Harness run still at IMPLEMENTATION: `result` is refused with "Context is STALE" (the in-scope files changed during implementation, likely pubspec.yaml/lock for `xml`). Refreshing needs `reopen`, which voids the technical approval, so this waits for the user.
Remaining: code review, device QA (open qa-deck.pptx from Browse; the adb VIEW intent only reached the app already open), release 1.0.8 (needs approval). Not committed.

## Release (2026-10-23)
User asked "commit with release tag": committed and tagged v1.0.8 (1.0.8+10), not pushed. Still open: the harness run never reached QA/RELEASE (PPTX run at IMPLEMENTATION with stale context; Word run at REVIEW), and device QA was not done. Close both runs (reopen/refresh as needed) and run the device checks before the next release.
