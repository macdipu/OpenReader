# ARCH-OPENDOCS-P2: PDF Reader (BRD Phase 2)

## Status
Proposed — pre-implementation. Blocked on the PDF library decision below before any code is written.

## Requirements Covered
ODF-011, ODF-012, ODF-008 (for PDF), ODF-P2-01 through ODF-P2-06 (see `SRS.md`).

## Existing Patterns / Components Reused
Identified before proposing anything new (per `agentic/data/project-context/modules/app.yaml`, Phase 1's own `ARCHITECTURE.md`, and direct inspection of the current code):
- `BaseController`/`StateStatus`/`Failure`/`Either` convention — the new `PdfReaderController` extends `BaseController` like every other Phase 1 controller.
- GetX routing/binding (`AppPages`, `Get.lazyPut(..., fenix: true)`), matching the pattern TASK-007's File Information route already added.
- **`DocumentInteractionController` is reused wholesale, not reimplemented per reader.** `toggleFavorite`, `shareDocument`, `openWithExternalApp`, and the `_verifyStillAccessible` guard (ODF-021/023) already exist and are format-agnostic — the PDF reader screen calls the same controller Home/Files/Search/Recents/Favorites already use, via `Get.find<DocumentInteractionController>()`, exactly like `FileInformationController` already does (`file_information_controller.dart:22`). File Information's own screen also works for a PDF document unchanged, since it never depended on a reader existing.
- `DocumentInteractionController.openDocument()` (`document_interaction_controller.dart:79`) is the exact seam this phase fills in: today it's a stub after the accessibility guard passes; this phase adds a category dispatch (`if (document.category == DocumentCategory.pdf) Get.toNamed(AppRoutes.pdfReader, arguments: document)`, falling through to the existing stub message for every other category, since Phase 3/4 readers don't exist yet).
- `recent_documents.reading_position` (already a generic JSON column, `app_database.dart:57`) and `RecentRepository.markOpened(documentId, readingPosition:)` (already accepts an arbitrary map) — no schema migration for ODF-008.

## Component Responsibilities (proposed)
- **`PdfReaderView`**: the reader screen — page display, zoom/pan gestures, app bar (back/filename/search/favorite/overflow per BRD §9.10), bottom controls (page indicator, thumbnail toggle, jump slider, view-mode switch).
- **`PdfReaderController extends BaseController`**: owns view-mode/zoom/current-page reactive state, drives search (query → result set → highlight → prev/next), triggers `RecentRepository.markOpened()` on page change (debounced, not per-frame) and on screen exit, delegates favorite/share/open-with to `DocumentInteractionController`.
- **A thin wrapper around whichever library is chosen** (name TBD by the ADR) — kept as a seam so the concrete PDF engine isn't referenced directly from `PdfReaderController`, matching how `StorageAccessService` is the only caller of `permission_handler` today. This also bounds the blast radius if the library choice needs revisiting later (e.g., a Community License eligibility change).
- **Password flow**: a dialog (reusing `showAppDialog` from `core/presentation/widgets/show_dialog/show_dialog.dart`, the same helper Recents' "Clear all" confirmation already uses) rather than a new dialog primitive.

## Data / Control Flow
```
DocumentInteractionController.openDocument(document)
        | (accessibility guard passes, category == pdf)
        v
Get.toNamed(AppRoutes.pdfReader, arguments: document)
        v
PdfReaderBinding --(document)--> PdfReaderController --> [chosen library's document/page controller]
        |                                  |
        |                          page/zoom/search state
        |                                  v
        |                    RecentRepository.markOpened(id, readingPosition: {...})  (debounced + on exit)
        v
DocumentInteractionController (unchanged) <-- Favorite / Share / Open With / File Information actions
```

## Contracts Affected
New: whatever thin wrapper interface the ADR's chosen library needs (not specified until that decision is made, to avoid designing an abstraction around a library that isn't picked yet). No existing contract's signature changes; `DocumentInteractionController.openDocument()` gains an internal branch, not a new public signature.

## Failure Handling
Reuses the existing `Either<Failure, T>`/`runTask` convention for anything that goes through a repository (e.g., `markOpened`). Reader-internal failures (corrupted PDF, unsupported encryption, out-of-memory protection — BRD §13) are UI-level states on `PdfReaderController.status`/`errorMessage` (the same `StateStatus.error` + `DocumentLoadErrorView` pattern already used everywhere else), not modeled as repository failures, since nothing about them is persisted.

## Security Boundaries
No new permission is requested — the PDF file is already readable via the existing `MANAGE_EXTERNAL_STORAGE` grant (ADR-OPENDOCS-storage-access). The only new boundary is: PDF parsing itself now runs on user-supplied, potentially malformed input (BRD §12.5 "malicious malformed document," "unsupported encryption type"). All four library alternatives below parse via a native/PDFium layer rather than a hand-rolled parser, which is the safer default; none of them were audited line-by-line here (out of scope for an architecture pass — a security-review pass on the chosen library's changelog/CVE history before shipping is recommended, not performed).

## Alternatives Considered
Verified directly against each package's pub.dev listing, README, and LICENSE file (not from general recollection, since three of the four were updated after this assistant's knowledge cutoff):

| Library | License | Flutter SDK floor | Feature coverage vs. BRD §9.10 | Maintenance |
|---|---|---|---|---|
| **`pdfx` 2.11.0** | MIT | `>=3.29.0` (compatible with this project's pinned 3.44.4) | Rendering + zoom/pan/scroll-direction widgets only. No search, thumbnails, TOC, password-dialog UI, or hyperlink handling in the package itself — confirmed by reading its README, which documents only `PdfController`/`PdfView`/`PdfViewPinch` and page-to-image rendering. All of ODF-P2-03/05/06 would be custom-built on top of its page-render primitive. | Active (published 2026-08-20) |
| **`flutter_pdfview` 1.4.5** | MIT | `>=3.32.0` (compatible) | Wraps the native Android/iOS PDF view as a `PlatformView`. Basic viewing only; being a platform view (not Flutter-rendered), custom overlays like search-result highlighting are difficult to build well. | Active (published 2026-08-03) |
| **`syncfusion_flutter_pdfviewer` 34.2.8** | **Syncfusion Essential Studio license** — free only under the Community License (org gross revenue < $1M/year **and** fewer than 5 developers), otherwise a paid commercial license is required (verified by reading the package's own `LICENSE` file) | `>=3.35.1` (compatible) | Covers nearly the entire BRD §9.10 list out of the box: built-in text search with highlighting, bookmark/TOC panel, page thumbnails, password-protected PDF handling, zoom, and multiple scroll/page layout modes. By far the least custom engineering. | Very active (published 2026-09-15) |
| **`pdfrx` 2.6.1** | Open source (BSD-style per repo) | **`>=3.47.0`** | Rich feature set (viewing, text, editing/combining) per its own description | **Ruled out for now**: requires a newer Flutter than this project's pinned `.fvmrc` (3.44.4) — adopting it means also deciding to bump the Flutter SDK, a separate, larger decision this architecture pass does not make unilaterally |
| ~~`native_pdf_view`~~ | MIT | — | — | **Ruled out**: last published 2022-02-10, effectively unmaintained |

**No recommendation is made here between `pdfx`/`flutter_pdfview` (free, more engineering effort, slower to reach full §9.10 parity) and `syncfusion_flutter_pdfviewer` (fastest path to full parity, but gated by a revenue/team-size-qualified Community License or a paid one).** Which side of that tradeoff is acceptable depends on OpenDocs' actual organizational size/revenue and appetite for a paid dependency — information this architecture pass does not have and should not assume, per AGENTS.md's "never invent missing business rules."

## Migration / Rollback Impact
None to the database (see Data Rules in `SRS.md`). Purely additive: a new route, a new controller/view, one new branch in `openDocument()`. Rollback is reverting whatever commit(s) implement this phase; nothing else depends on the reader existing yet (`TASK-009` explicitly waits for it, so its own work would need to wait longer, not break).

## Risks
1. **The library decision blocks everything else** — no task breakdown below can be estimated accurately until it's resolved, since the `pdfx`/`flutter_pdfview` path implies building search/thumbnails/password UI as first-party OpenDocs code (multiple additional stories), while Syncfusion implies mostly wiring an existing widget (far fewer).
2. **Large/complex PDFs** (BRD §12.6 "5,000+ pages," huge image-only PDFs) risk the existing scanner-adjacent lesson from Phase 1 (ODF-030, still unverified) repeating for readers specifically — BRD §14 already calls for lazy loading and bounded memory; whichever library is chosen needs to be checked against a large test corpus before this phase is called done, not assumed fine.
3. **Password/encryption handling correctness** (BRD §12.5) has real security weight — a wrong implementation could either fail to prompt for genuinely encrypted files or mishandle unsupported encryption types in a way that looks like success. Needs explicit test coverage against BRD's own error message table (§13), not just the happy path.

## ADR Recommendation
**Recommended before implementation starts**: `ADR-OPENDOCS-pdf-library.md`, comparing `pdfx`+custom engineering vs. `flutter_pdfview`+custom engineering vs. `syncfusion_flutter_pdfviewer`, with an explicit decision on whether OpenDocs qualifies for (or is willing to pay for) Syncfusion's license. This mirrors `ADR-OPENDOCS-storage-access`'s role for TASK-007: a real alternatives-with-tradeoffs decision that affects both engineering scope and, this time, a possible ongoing licensing cost — not something to silently settle inside a task. Not drafted yet, pending the product owner's input on the licensing question (see `SRS.md` Unresolved Specification Question 1).

## References
- `SRS.md` (this feature)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P1/ARCHITECTURE.md`, `TECH-SPEC.md` (patterns reused)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P1/adr/ADR-OPENDOCS-storage-access.md` (ADR process precedent)
- BRD §9.10, §10, §12, §13, §14, §16, §30 (Phase 2)
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/core/data/local/app_database.dart`
- pub.dev/GitHub for `pdfx`, `flutter_pdfview`, `syncfusion_flutter_pdfviewer`, `pdfrx`, `native_pdf_view` (versions and licenses verified 2026-09-18)
