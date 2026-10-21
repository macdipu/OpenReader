# CR-OPENREADER-UX Phase 1: code review (2026-10-21)

**Reviewer: the implementing agent.** This is not an independent review. An independent reviewer agent was launched twice; both attempts terminated on an API network error (`ENOTFOUND`) before reporting any findings. This review was then done by the same agent that wrote the code. Weigh it accordingly: an agent review is not human approval.

## Verdict
**READY, no material defects found.** Scope: the working-tree diff against `3a13d40` under `lib/`, `test/` and `android/`.

## Checks performed
1. **Reader Scaffold rebuild on search toggle (UX-05).** Highest-risk item. Traced in library source:
   - **pdfrx 2.4.8** `_PdfViewerState._widgetUpdated` (`pdf_viewer.dart:370-383`) returns early when `documentRef.key` is unchanged. `PdfDocumentRefKey` equality is `sourceName` + `parts` (`pdf_document_ref.dart:35`), derived from the file path, so the document is **not reloaded**. The same rebuild already happened before this change whenever `textSearcher` attached.
   - **docx_file_viewer 1.0.4** `DocxView.didUpdateWidget` (`docx_view.dart:140-147`) reloads only if `file`, `bytes` or `path` changes by identity. The view always passes the same `validatedBytes` instance, so there is **no reload**.
   - **Excel, CSV and Text:** their bodies are first-party widgets; their scroll controllers live in the GetX controller, so state is preserved.
2. **State transitions (`beginLoad`).**
   - Initial or error goes to `loading`, which shows the full spinner.
   - Success, empty or refreshing goes to `refreshing`, and the content stays mounted.
   - Home/Files `refresh()` sets `refreshing` and then `load()` keeps it, so the scan banner shows.
   - A failure during a refresh still goes to `error` and shows the error view with Retry. The existing retry tests pass.
3. **Empty-state copy during refresh.** One defect was found here and fixed before review: Home could show "No reading history yet" during a first scan. Home and Files now decide the empty state from the data.
4. **Debounce.** The Files timer is cancelled on each keystroke and in `onClose`. A pending timer firing after a category change reloads with the current state, so no stale query is possible.
5. **Callers of the old semantics.** All `isBusy` uses were enumerated. Readers and File Information still use `isBusy`; they load once. Reader controller tests poll `isBusy` and are unaffected.
6. **`.doc`/`.xls` removal.**
   - Scanner, file picker and the incoming resolver all derive from `DocumentCategory`.
   - Android VIEW/SEND filters were updated.
   - No iOS, macOS, Windows or Linux document-type declarations exist (searched). The scanner test iterates over `supportedExtensions`, so it adapts.
   - Onboarding copy still says "Word, Excel", which remains accurate for `.docx`/`.xlsx`.
7. **Do the tests discriminate?** Each new test fails on the old code:
   - The old `load()` set `loading`, not `refreshing`.
   - The old app bar was always 96px.
   - The old clear left the text in the field.
   - `fromExtension('doc')` was `word`.
   - The old label was "No searchable text found.".

## Findings
- **PLAUSIBLE, low:** `SearchDocumentsController.queryController` is disposed in `onClose`. If GetX deleted the controller before the route's exit transition finished, the still-mounted `TextField` could touch a disposed controller. This is the common GetX pattern, and GetX deletes route controllers after removal, but it has not been verified on a device. Direction: none needed unless an error shows up in QA.
- **Optional:** AC5 is exercised on the Text reader only. The other four readers share the identical code shape, applied by one script with per-file match assertions.
- **Deferred (documented):** the PDF zero-match label (BRD scanned-PDF message) and UX-07 PowerPoint.

## Remaining verification gaps
No device or visual check yet; this belongs to QA. Emulators are available on this host (`Pixel_4a`, `Pixel_4a_2`, plus the iOS Simulator and macOS desktop).
