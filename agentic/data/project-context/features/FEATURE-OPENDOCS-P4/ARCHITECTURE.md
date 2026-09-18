# ARCH-OPENDOCS-P4: Text/CSV Readers and Platform Integration (BRD Phase 4)

## Status
**Implemented** (2026-09-18) — see `tasks/TASK-012.md` for the as-built design and delta; this document is preserved as the pre-implementation design record, not updated in place. Unlike `FEATURE-OPENDOCS-P2`/`P3`, **no new dependency decision was needed** for either reader (see Alternatives Considered), so no ADR exists for this phase — flagged explicitly so its absence isn't mistaken for an oversight.

## Requirements Covered
ODF-019, ODF-020, ODF-008 (for TXT/CSV), ODF-P4-01 through ODF-P4-05 (see `SRS.md`).

## Existing Patterns / Components Reused
- `BaseController`/`StateStatus`/`Failure`/`Either`/`runTask`, GetX routing/binding — same shape as every reader since `FEATURE-OPENDOCS-P1`.
- `DocumentInteractionController` reused wholesale again: `toggleFavorite`/`shareDocument`/`openWithExternalApp`/`_verifyStillAccessible`.
- `DocumentInteractionController.openDocument()` gains `text`/`csv` branches in its existing `switch`, following `FEATURE-OPENDOCS-P3/TASK-011`'s exact pattern (each reader owns its own `markOpened` calls; a bare call in `openDocument()` would still reset an existing position).
- `RecentRepository.getPosition()`/`markOpened(readingPosition:)` — reused as-is.
- **`excel_plus`'s CSV parser** (`Excel.fromCsv`, `CsvConfig`), already a project dependency since `FEATURE-OPENDOCS-P3` — reused for CSV rather than adding a new CSV library or hand-rolling a parser. This directly avoids re-solving BRD §9.15's hardest corner cases (quoted commas, multi-line quoted values) with new, unproven code; `excel_plus`'s CSV import path is part of its own tested surface.
- **The Excel reader's grid widget**, extracted from `FEATURE-OPENDOCS-P3`'s `ExcelReaderView` (currently `_Grid`, file-private) into a shared, reusable widget. The CSV reader needs the identical capability (frozen header row, two-axis scroll, cell-based rendering) over the identical underlying shape (`List<List<xls.Data?>>` from `excel_plus`, since `Excel.fromCsv` produces a normal `Excel`/`Sheet` object) - reusing it outright avoids duplicating the scroll-sync logic `TASK-011` already built and verified.

## Component Responsibilities (proposed)
- **`TextReaderController extends BaseController`**: reads the file's bytes, decodes with the UTF-8-first/Latin-1-fallback heuristic (`SRS.md` Unresolved Question 3), owns a real `ScrollController` (unlike the Word reader — this reader isn't wrapping an opaque third-party widget, so position save **and** restore both work here), drives search over the decoded text (a plain case-insensitive substring scan, same shape as every other reader's search), and owns text-size/line-wrap toggle state.
- **`TextReaderView`**: for a normal-sized file, a single scrollable `SelectableText` (or `TextField(readOnly: true, maxLines: null)` if selection styling needs are simpler); for a large file (see Risks), a lazily-loaded line-windowed list instead of one giant `Text` widget, to hold BRD §14's "near-instant" TXT-open target and bounded memory (§9.14 Corner Case: "Very large text file"). Which of the two a given file uses is a runtime decision (file size threshold), not two separate reader implementations.
- **`CsvReaderController extends BaseController`**: parses via `Excel.fromCsv` (or `Excel.decodeBytesAsync`-equivalent for CSV bytes — needs checking whether `excel_plus` exposes an isolate-friendly CSV entry point for large files, or whether that only applies to `.xlsx`; if not, large CSVs parse on the main isolate, a real, flagged risk below). Otherwise structurally identical to `ExcelReaderController` minus sheet-tab logic (CSV has one implicit sheet) — proposed to actually share a common base class or mixin with `ExcelReaderController` for the row/search/position logic they'd otherwise duplicate, decided during implementation rather than designed in detail here.
- **`CsvReaderView`**: the shared grid widget (see above) plus a header-row toggle if Unresolved Question 1's default (assume header) needs a user override — not committed to in this document, since it adds a control surface BRD doesn't explicitly ask for.

## Data / Control Flow
```
DocumentInteractionController.openDocument(document)
        | (accessibility guard passes, category == text|csv)
        v
Get.toNamed(AppRoutes.textReader|csvReader, arguments: document)
        v
<Format>ReaderBinding --(document)--> <Format>ReaderController --> [dart:io file read] --or--> [excel_plus CSV parse]
        |                                        |
        |                                scroll/row/column position
        |                                        v
        |                    RecentRepository.markOpened(id, readingPosition: {...})  (debounced + on exit)
        v
DocumentInteractionController (unchanged) <-- Favorite / Share / Open With / File Information actions
```
Identical shape to every prior phase, parameterized over two more formats.

## Contracts Affected
- The Excel grid widget's extraction changes its visibility/location (from `ExcelReaderView`-private to shared), not its behavior — `ExcelReaderView` itself should be a thin wrapper around the shared widget afterward, functionally unchanged. This is a refactor with test-coverage implications: `FEATURE-OPENDOCS-P3/TASK-011`'s existing Excel tests must still pass unmodified after the extraction, or the refactor has broken something.
- No other existing contract's signature changes.

## Failure Handling
Same `StateStatus`/`errorMessage` pattern as every prior reader. TXT-specific: a decode failure (BRD §9.14 Corner Case "Binary file renamed as `.txt`") is caught and mapped to the existing generic corrupted-file message, not rendered as garbage text.

## Security Boundaries
No new permission. TXT has no container format to exploit (unlike Office's ZIP-based formats) - reading arbitrary bytes and decoding them as text has no code-execution surface. CSV shares Office's general "untrusted structured input" caution in spirit, but `excel_plus`'s CSV path is plain-text parsing, not a ZIP/XML container - no equivalent to BRD §12.5's "ZIP bomb"/"path traversal in packaged Office files" corner cases applies here.

## Alternatives Considered

Unlike `FEATURE-OPENDOCS-P2`/`P3`, this phase's research concluded **no new dependency is needed at all**, for either format:

| Format | Option | Verdict |
|---|---|---|
| TXT | Flutter's own `Text`/`SelectableText`/`TextField` widgets over `dart:io` file bytes | **Chosen.** No rendering library exists or is needed for plain text; this is the only sane approach. |
| TXT | A third-party "code viewer"/"text editor" package (e.g. syntax-highlighting editors) | **Rejected**: BRD asks for lightweight plain-text viewing, not code editing or syntax highlighting - pulling in an editor-grade dependency for a feature that doesn't need one would be unjustified scope creep, not "preferring existing implementations." |
| CSV | `excel_plus`'s `Excel.fromCsv`/`CsvConfig` (already a dependency) | **Chosen.** Already vetted (`ADR-OPENDOCS-office-libraries`), already handles quoting/escaping correctly, already produces the exact `Sheet`/`Data` shape the reused grid widget expects. |
| CSV | A dedicated CSV package (e.g. `csv` on pub.dev) | **Rejected**: would duplicate parsing capability already present and already a dependency, for no clear benefit - violates "prefer existing implementations" for no offsetting gain. Would only be worth revisiting if `excel_plus`'s CSV path turns out to have a real limitation during implementation (e.g. no isolate-friendly entry point for very large CSVs - see Risks). |

## Migration / Rollback Impact
None to the database (same reasoning as every prior phase). Purely additive: two new routes/controllers/views, two new branches in `openDocument()`, plus the Excel-grid extraction refactor (behavior-preserving, covered by existing tests). Rollback is reverting whichever reader(s) shipped.

## Risks
1. **Large-file handling is unverified for both formats** (BRD §9.14/9.15: "Very large text file," "1M+ rows") - the line-windowing approach proposed for TXT and whatever CSV's large-file strategy turns out to be are both design proposals, not proven against a real large-file test corpus. Same posture every prior phase has carried forward for its own large-file risk (`FEATURE-OPENDOCS-P2` Risk 2, `FEATURE-OPENDOCS-P1` ODF-030).
2. **`excel_plus`'s CSV parsing has no isolate-friendly entry point** - confirmed by reading `lib/src/core/csv.dart`: `Excel.fromCsv`/`CsvConfig`'s import path is fully synchronous, with no `Future`/`Isolate`-based variant the way `Excel.decodeBytesAsync` exists for `.xlsx`. A 1M-row CSV (BRD's own stated corner case) would parse on the main isolate and could jank the UI, contradicting BRD §14's "UI remains responsive" principle. Implementation should wrap the parse call in `Isolate.run`/`compute` itself if this matters for the first slice, rather than assuming the library handles it.
3. **Encoding detection's narrow scope** (UTF-8-first/Latin-1-fallback only) means a file in another encoding (e.g. UTF-16 without a clear BOM, or a non-Latin legacy codepage) renders incorrectly rather than correctly - an accepted, documented limitation per BRD's own "where feasible" hedge, not silently assumed solved.
4. **The Excel-grid extraction touches already-shipped, already-tested code** (`FEATURE-OPENDOCS-P3`) - low risk if done as a pure refactor with the existing test suite as the safety net, but worth calling out as the one part of this phase that isn't purely additive.

## ADR Recommendation
None. No new dependency, no licensing question, no library alternatives to weigh - this phase's only "decision" (reuse `excel_plus` for CSV instead of a dedicated CSV library) is a direct, low-risk consequence of `ADR-OPENDOCS-office-libraries` already being accepted, not a new decision warranting its own record.

## References
- `SRS.md` (this feature)
- `FEATURE-OPENDOCS-P3/ARCHITECTURE.md`, `tasks/TASK-011.md` (the Excel grid this phase reuses, and the pattern this phase follows)
- `lib/core/domain/models/document_category.dart` (confirmed `text`/`csv` enum values already exist)
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/core/data/repositories/recent_repository_impl.dart`, `lib/features/excel_reader/presentation/excel_reader_view.dart`
- BRD §9.14, §9.15, §10, §12, §13, §14, §16, §30 (Phase 4)
