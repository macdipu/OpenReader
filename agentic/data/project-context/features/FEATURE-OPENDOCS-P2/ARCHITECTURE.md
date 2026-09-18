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
Verified directly against each package's pub.dev listing, README, CHANGELOG, and LICENSE file (not from general recollection, since these packages were updated after this assistant's knowledge cutoff):

| Library | License | Flutter SDK floor | Feature coverage vs. BRD §9.10 | Maintenance |
|---|---|---|---|---|
| **`pdfx` 2.11.0** | MIT | `>=3.29.0` (compatible with this project's pinned 3.44.4) | Rendering + zoom/pan/scroll-direction widgets only. No search or thumbnails in the package itself. Its `password` parameter is documented as **"supported only for web"** — it does not work on Android/iOS, the app's actual target platforms (confirmed by reading `PdfDocument.openFile`'s doc comment in source). All of ODF-P2-03/05/06 would need custom engineering, and ODF-P2-05 (password) specifically has no native-platform path through this package at all. | Active (published 2026-08-20) |
| **`flutter_pdfview` 1.4.5** | MIT | `>=3.32.0` (compatible) | Wraps the native Android/iOS PDF view as a `PlatformView`. `password` works on both platforms (confirmed in its README's parameter table). Search is listed in the maintainer's own "Future plans" — not implemented. Being a platform view, custom overlays (search-result highlighting) are difficult to build well even once search exists. | Active (published 2026-08-03) |
| **`syncfusion_flutter_pdfviewer` 34.2.8** | **Syncfusion Essential Studio license** — free only under the Community License (org gross revenue < $1M/year **and** fewer than 5 developers), otherwise a paid commercial license is required (verified by reading the package's own `LICENSE` file) | `>=3.35.1` (compatible) | Covers nearly the entire BRD §9.10 list out of the box. Ruled out per the product owner's explicit "don't want to pay anything" — the Community License's revenue/team-size gate is a real, unverifiable-here eligibility condition, not a formality. |  |
| **`pdfrx` 2.4.8** (pinned, not latest `2.6.1`) | MIT | `>=3.41.0` — **compatible with this project's pinned 3.44.4; no Flutter SDK bump needed** | Built-in text selection/search and a real `PasswordProvider`/`PdfPasswordException` mechanism working on Android/iOS, both confirmed already present at 2.4.8 via the package CHANGELOG (2.4.8's own entries are bug fixes *to* text selection, meaning the feature predates it; password support was introduced many versions earlier still). Only the Flutter SDK requirement jumped to `3.47.0` starting at version `2.5.0` — pinning to the last `3.41.0`-floor release avoids that entirely. **Verified for real**: added `pdfrx: 2.4.8` to this project's `pubspec.yaml` and ran `flutter pub get` — resolved cleanly (11 new/changed transitive packages, no conflicts) against the existing ~60 dependencies; `flutter analyze` afterward still showed 0 errors/warnings (158 pre-existing infos, unchanged baseline). Reverted before committing, pending this decision being made explicitly rather than assumed. No thumbnail-strip or jump-to-page *widgets* ship with it — those are custom OpenDocs UI built on its page-image/page-controller primitives, same as would be true for any of these libraries. | Active (published 2026-09-04) |
| ~~`native_pdf_view`~~ | MIT | — | — | **Ruled out**: last published 2022-02-10, effectively unmaintained |

**Recommendation: `pdfrx: 2.4.8`.** It's the only free (MIT) option that already covers both of BRD's hard-to-fake requirements — text search and real (non-web-only) password support — without custom engineering for either, and it needs no Flutter SDK bump. `pdfx`/`flutter_pdfview` were the free alternatives originally considered; both would require building at least one of search or password from scratch, and neither is a smaller lift than adopting a slightly older `pdfrx` release. Syncfusion is ruled out per the product owner's stated "don't want to pay anything," which resolves what was previously an open licensing question — recorded as a decision here rather than left pending.

## Migration / Rollback Impact
None to the database (see Data Rules in `SRS.md`). Purely additive: a new route, a new controller/view, one new branch in `openDocument()`. Rollback is reverting whatever commit(s) implement this phase; nothing else depends on the reader existing yet (`TASK-009` explicitly waits for it, so its own work would need to wait longer, not break).

## Risks
1. **Pinning `pdfrx` below latest (2.4.8 vs. 2.6.1) means missing 2.5.0+'s bug fixes** (WASM/text-search edge cases, a Windows race condition, progressive-loading fixes per the CHANGELOG) until the project's own Flutter SDK is eventually bumped past 3.47.0 — an accepted, explicit tradeoff for staying on the current SDK, not an oversight. Revisit the pin whenever `.fvmrc` is next bumped.
2. **Large/complex PDFs** (BRD §12.6 "5,000+ pages," huge image-only PDFs) risk the existing scanner-adjacent lesson from Phase 1 (ODF-030, still unverified) repeating for readers specifically — BRD §14 already calls for lazy loading and bounded memory; `pdfrx` needs to be checked against a large test corpus before this phase is called done, not assumed fine.
3. **Password/encryption handling correctness** (BRD §12.5) has real security weight — a wrong implementation could either fail to prompt for genuinely encrypted files or mishandle unsupported encryption types in a way that looks like success. Needs explicit test coverage against BRD's own error message table (§13) using `pdfrx`'s `PasswordProvider`/`PdfPasswordException`, not just the happy path.
4. **Thumbnails and jump-to-page are custom UI**, not library-provided widgets — built on `pdfrx`'s page-image/page-controller primitives. Reasonable scope (Phase 1's `DocumentScannerService`-style "pure function over a primitive" pattern applies), but real work, not a checkbox.

## ADR Recommendation
**Drafted**: [ADR-OPENDOCS-pdf-library](adr/ADR-OPENDOCS-pdf-library.md) (Status: Proposed, not yet approved) records `pdfrx: 2.4.8` as the choice — the product owner ruled out any paid dependency, which resolves `SRS.md`'s Unresolved Specification Question 1 without needing further input. The ADR's value is the same as `ADR-OPENDOCS-storage-access`'s: a durable record of the alternatives ruled out and why (Syncfusion's licensing gate, `pdfx`'s web-only password support, `flutter_pdfview`'s missing search, `pdfrx` latest's Flutter SDK floor), so a future contributor doesn't have to redo this research. Still needs explicit approval before implementation starts, per AGENTS.md ("artifact creation is not approval").

## References
- `SRS.md` (this feature)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P1/ARCHITECTURE.md`, `TECH-SPEC.md` (patterns reused)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P1/adr/ADR-OPENDOCS-storage-access.md` (ADR process precedent)
- BRD §9.10, §10, §12, §13, §14, §16, §30 (Phase 2)
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/core/data/local/app_database.dart`
- pub.dev/GitHub for `pdfx`, `flutter_pdfview`, `syncfusion_flutter_pdfviewer`, `pdfrx`, `native_pdf_view` (versions and licenses verified 2026-09-18)
