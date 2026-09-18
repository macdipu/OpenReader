# Engineering Task

## Status
DONE (implemented, `flutter analyze`/`flutter test` verified) — 2026-09-18. Implemented directly against `SRS.md`/`ARCHITECTURE.md` scoping in this session ("Approve it, start implementation"), without a separate planned-LLD document; this task doc records the as-built design and its delta from that scoping pass.

## Story
PDF Reader (BRD §9.10, Phase 2)

## Objective
ODF-011 (offline PDF rendering), ODF-012 (text search), ODF-008 (reading-position restore for PDF), and ODF-P2-01…06 (view modes, zoom, thumbnails, jump-to-page, password flow, search+highlight).

## Dependencies
- `ADR-OPENDOCS-pdf-library.md` — **Accepted**, `pdfrx: 2.4.8`.
- `DocumentInteractionController` (TASK-007) — reused wholesale for Favorite/Share/Open With; not reimplemented.
- `RecentRepository` — extended (see delta) rather than replaced.

## Implementation Requirements (as built)
- **Dependency**: `pdfrx: 2.4.8` pinned exactly (not a caret range) in `pubspec.yaml`, with a comment pointing at the ADR, because `2.5.0+` raises the Flutter SDK floor above this project's `.fvmrc` pin (3.44.4).
- **Reading position**: `RecentRepository.getPosition(documentId)` added (reuses the existing generic JSON `reading_position` column from Phase 1 — no schema migration). `PdfReaderController` owns its own `markOpened` calls (initial restore in `onInit`, debounced per-page-change save, final save on `onClose`) instead of `DocumentInteractionController.openDocument()` calling it — a bare call there would reset an existing position back to `{}` before the reader even reads it.
- **Routing**: `DocumentInteractionController.openDocument()` now dispatches `DocumentCategory.pdf` to `AppRoutes.pdfReader` via `Get.toNamed`, instead of showing the "not part of this build yet" stub. All other categories are unchanged.
- **Feature module**: `lib/features/pdf_reader/presentation/` — `PdfReaderController`, `PdfReaderView`, `PdfPasswordDialog`, `PdfReaderBinding`, following the same controller/view/binding shape as `file_information`.
- **View modes**: two shipped — `continuous` (pdfrx's default vertical scroll) and `horizontal` (paged, via pdfrx's documented custom `layoutPages` recipe). BRD §9.10 lists three ("Single-page," "Continuous vertical," "Horizontal page"); a true single-page scroll-snap mode was not built as a distinct third option — pdfrx's pan-based viewer has no scroll-snap primitive, and `horizontal` already covers discrete one-page-at-a-time navigation. Flagged here as a deliberate, documented scope reduction, not a silent gap.
- **Password flow**: `PdfViewerParams.passwordProvider` wired to `PdfReaderController.providePassword()`, which shows `PdfPasswordDialog` via the shared `showAppDialog` helper; cancelling leaves the reader (`Get.back()`) instead of surfacing a raw exception banner.
- **Search**: `PdfTextSearcher` drives highlighting (`pagePaintCallbacks`) and a status bar showing match count / "No searchable text found." (BRD §13 exact string) / "Searching…".
- **Thumbnails**: `PdfDocumentViewBuilder` + `PdfPageView` reuse the main viewer's `documentRef`, avoiding opening the file a second time.
- **Errors**: `errorBannerBuilder` shows the generic BRD §13 "This document may be damaged or incomplete." with Close / Try another app (delegates to `DocumentInteractionController.openWithExternalApp`). Password failures never reach this banner — `providePassword()` handles cancellation itself.

## Implementation delta (2026-09-18)

One real, non-hypothetical bug was found and fixed during implementation, not just an environment limitation: `pdfrx`'s `PdfTextSearcher` constructor dereferences the viewer controller's live document immediately (`controller!.document.events.listen(...)`, where `controller` is null until `PdfViewerController.isReady`). The original design built it as a `late final PdfTextSearcher textSearcher = PdfTextSearcher(pdfController)` field, first accessed from `PdfReaderView._buildViewer()` during the very first widget build — before the viewer has any document attached. That throws a null-check crash on every attempt to open the reader. Confirmed directly (not assumed) via a standalone construction test before the fix, and confirmed fixed after. Fixed by changing `textSearcher` to `Rxn<PdfTextSearcher>`, constructed only inside `onViewerReady` once the document is actually attached, with every call site (`stopSearching`, `onSearchQueryChanged`, `goToNextMatch`/`goToPrevMatch`, `onClose`, the search icon's enabled state, `_SearchStatusBar`) updated to treat it as possibly null until then. The search icon is now disabled until the document is ready rather than silently no-opping.

A second, unrelated pre-existing bug was found and fixed because it blocked this feature: `lib/res/routes/global_navigator.dart`'s `rootContext` read from a `rootNavigatorKey` `GlobalKey` that was never attached to any widget — `app.dart` wires a *different* key (`NavigationService.navigatorKey`) into `GetMaterialApp.navigatorKey`. This meant `showAppDialog` (which `providePassword()` depends on to show `PdfPasswordDialog`), `showAppSheet`, and `CustomSnackbar.showGlobalToast` were all silently no-opping in production. Also silently broken by the same bug, discovered as a side effect: Recents' pre-existing "Clear all" confirmation dialog (Phase 1, untested). Fixed by making `rootContext` delegate to `NavigationService.navigatorKey.currentContext` and removing the dead key. Verified via `flutter analyze` (same 158-info baseline, 0 new issues) and the full `flutter test` run below (which exercises Recents' existing suite unchanged).

**Verified gaps, not silently claimed as done:**
1. **No native PDF rendering verification.** This environment's Flutter SDK installation (fetched via `pub get` only) has no native PDFium `.so` for Linux and no native-assets fallback — confirmed directly by attempting to open a hand-built minimal PDF via `PdfDocument.openFile()` in a test, which failed with a clear "Failed to load PDFium module" error. Building the Linux native toolchain was judged not worth pursuing since Android, not Linux desktop, is the actual target platform. Actual rendering, zoom gestures, and real password/search behavior against a real PDF are unverified in this environment and remain a device-verification item, consistent with how TASK-007 already treated platform-level checks.
2. **`providePassword()`'s dialog flow is not covered by an automated test** — exercising it needs the full `NavigationService`/`GetMaterialApp` navigator wiring live, which the test suite's lighter `GetMaterialApp(home: ...)` fixtures don't set up. Left as a device-verification item alongside gap 1, rather than built out with disproportionate test scaffolding for a flow that can't be verified end-to-end here anyway.

**Validation:** `flutter analyze`: 0 errors, 0 warnings (158 pre-existing infos — same baseline as TASK-007/008). `flutter test`: 65/65 passing (51 pre-existing + 14 new, in `test/controllers/pdf_reader_controller_test.dart`) covering initial-position restore (including malformed/non-positive `page_number` handling), debounced position-save logic (via `fake_async`, including debounce-reset on rapid page changes and a null-page no-op), `onClose`'s safety when the viewer was never attached (the exact condition the `PdfTextSearcher` bug above would have crashed on) versus when a position needs a final save, view-mode/thumbnail toggling, `jumpToPage`'s before-ready guard, and delegation to `DocumentInteractionController` (favorite toggling; share/open-with's missing-file guard, matching TASK-007's own established pattern of leaving the platform-channel happy path to device verification).

## Acceptance Criteria
- ODF-011/012/008 and ODF-P2-01…06: met for everything `flutter analyze`/`flutter test` can verify in this environment; native rendering itself is an explicit device-verification gap (see delta, gap 1).
- Favorite/Share/File Information/Open With work identically inside the reader as elsewhere (reused, not reimplemented).
- BRD §13 exact error strings preserved: "This document may be damaged or incomplete.", "No searchable text found.", "This file may have been moved or deleted." (guard, shared with TASK-007).

## Test Requirements
`test/controllers/pdf_reader_controller_test.dart` — 14 tests, all passing. See delta above for what remains a device-verification gap.

## References
- `ADR-OPENDOCS-pdf-library.md`
- `SRS.md`, `ARCHITECTURE.md` (original scoping this task implements)
- `FEATURE-OPENDOCS-P1/tasks/TASK-007.md` (the `DocumentInteractionController`/accessibility-guard/test-pattern precedent reused here)
- `FEATURE-OPENDOCS-P1/tasks/TASK-009.md` (Open From Other Apps — was blocked on "at least one document reader existing"; a PDF reader now exists, so that blocker is partially cleared for PDF files specifically, though TASK-009 itself is not implemented here)

## Out of Scope
- TOC/bookmarks/hyperlink navigation (BRD §9.10) — deferred per `SRS.md` Unresolved Specification Question 2, not resolved by this task.
- A true single-page scroll-snap view mode — see delta above.
- TASK-009 (Open From Other Apps) — not implemented; only its "no reader exists" blocker is now partially addressed.
