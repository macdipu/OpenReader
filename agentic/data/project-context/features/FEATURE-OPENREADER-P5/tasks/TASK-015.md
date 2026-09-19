# Engineering Task

## Status
DONE (implemented, `flutter analyze`/`flutter test` verified) — 2026-09-19. Implements `SRS.md`/`ARCHITECTURE.md`'s first implementation slice, item (b): ODF-P5-03/04 Office ZIP/security hardening. No ADR needed — `archive` was already a transitive dependency (via `docx_file_viewer`/`excel_plus`), only promoted to direct; no new dependency, matching this phase's posture.

## Story
Office ZIP/security hardening (BRD Phase 5, hardening — Security / Corrupted-file)

## Objective
- ODF-P5-03: add a defensive ceiling (entry count / uncompressed size) before parsing DOCX/XLSX ZIP containers, rejecting before full decompression.
- ODF-P5-04: verify a password-protected Word/Excel file fails gracefully (existing generic corrupted-file message), not with a crash or hang.

## Dependencies
- `archive` (already transitive via `docx_file_viewer`/`excel_plus`; promoted to a direct `pubspec.yaml` dependency at `^4.3.0` since `ZipSafetyGuard` now imports it directly). No new dependency introduced.

## Implementation Requirements (as built)
- `lib/core/presentation/utils/zip_safety_guard.dart`: new `ZipSafetyGuard.check(bytes)` — reads a ZIP's central directory only via `ZipDecoder().decodeBytes()` (confirmed by reading `archive` 4.3.0's source that this never decompresses entry content) and returns `ZipSafetyResult.safe` / `.tooLarge` / `.corrupted`. Ceilings: `maxEntryCount = 10000`, `maxUncompressedBytes = 500MB` (first-pass, adjustable — same posture as `CsvReaderController.maxBytes`). Also rejects absolute paths and `..` traversal segments in entry names as `.corrupted`.
  - Real gap found and fixed during implementation: `ZipDirectory.read` doesn't throw when it can't find an End Of Central Directory record — it silently leaves `filePosition` at `-1` and `decodeBytes` then returns an *empty* `Archive`, which an early version of this guard misclassified as `.safe`. Fixed by checking `decoder.directory.filePosition < 0` (the `ZipDecoder` instance exposes its `directory` field after decoding) and treating that as `.corrupted`. Caught by this task's own unit tests, not downstream — see Validation.
- `ExcelReaderController._load()`: runs `ZipSafetyGuard.check(bytes)` right after `readAsBytes()`, before `xls.Excel.decodeBytesAsync(bytes)`. `.tooLarge` → existing "This document is too large to render safely on this device." (reused from the CSV reader, not new copy); `.corrupted` → existing "This document may be damaged or incomplete.".
- `WordReaderController`: previously never read the file itself — `DocxView(path: ...)` did that internally, so there was nowhere to put a pre-parse guard. Restructured to read bytes once in `_loadInitialPosition()` → `_loadAndValidateBytes()`, run the same guard, and expose the validated bytes via `validatedBytes` (only set on `.safe`). `WordReaderView` now renders `DocxView(bytes: controller.validatedBytes!, ...)` instead of `path:` (docx_file_viewer 1.0.4 supports a `bytes:` constructor param — confirmed by reading its source), avoiding a second read. `hasError`/`errorMessage` now also cover the pre-parse guard outcome, reusing the same two BRD §13 messages as Excel; `onLoadError` (DocxView's own internal-parse-failure callback) is unchanged and still covers failures the guard can't catch (e.g. a well-formed-but-safe ZIP whose XML content doesn't parse as OOXML).
- No new error copy anywhere — both readers reuse BRD §13's existing "too large" / "damaged or incomplete" messages, per `ARCHITECTURE.md`'s stated design boundary.

## Acceptance Criteria
- ODF-P5-03: met — both Office readers reject an oversized/malicious ZIP before `excel_plus`/`docx_file_viewer` decompress it.
- ODF-P5-04: met — a fixture shaped like a real password-protected `.docx`/`.xlsx` (see Validation) fails through the existing generic corrupted-file message, not a crash or hang.

## Validation
- `flutter analyze`: 0 errors, 0 warnings, 152 pre-existing infos (same baseline as TASK-013/014).
- `flutter test`: 134/136 passing (10 new tests added on top of the 122/124 baseline: 2 pre-existing failures unchanged, unrelated — see TASK-013).
- New tests:
  - `test/core/zip_safety_guard_test.dart` (7 cases): accepts a well-formed archive; rejects entry-count-over-ceiling; rejects uncompressed-size-over-ceiling built via a single `ArchiveFile` with a lying declared size and empty actual content (confirmed `ZipEncoder` writes the declared `entry.size`, not actual data length, into the central directory — this is what makes the check pre-decompression); rejects `../` and absolute-path entry names; rejects non-ZIP garbage bytes; rejects an OLE2 compound-file signature.
  - `test/controllers/excel_reader_controller_test.dart` / `word_reader_controller_test.dart` (+3 each): the same OLE2-signature and oversized-declared-size fixtures exercised end-to-end through each controller, asserting the existing user-facing messages fire.
- ODF-P5-04's fixture is **not** a real encrypted file — no encryption library was added or used. Real Office password-protection wraps the entire package in an OLE2 compound file (`EncryptedPackage`/`EncryptionInfo` streams), not a ZIP at all, so the fixture reproduces that container format's exact 8-byte signature (`D0 CF 11 E0 A1 B1 1A E1`). This is sufficient to verify the actual claim in ODF-P5-04 (fails gracefully, not a crash/hang) because the structural reason it must fail — "not ZIP-shaped" — is identical whether or not real encryption is layered on top; a genuinely encrypted fixture would exercise the same code path with no different signal, since neither Excel nor Word's chosen libraries were ever going to attempt decryption either way.

## References
- `SRS.md` ODF-P5-03/04, Unresolved Specification Question 1 (confirmed implementation order: item (b) after `.env`/CI)
- `ARCHITECTURE.md` ODF-P5-03/04 section, Security Boundaries table (ZIP-bomb guard: proposed/rejected alternatives)
- `docx_file_viewer` 1.0.4 source (`lib/src/docx_view.dart`) — confirmed `bytes:` constructor support
- `archive` 4.3.0 source (`lib/src/codecs/zip_decoder.dart`, `zip/zip_directory.dart`) — confirmed central-directory-only parsing and the silent-empty-archive-on-no-EOCD behavior

## Out of Scope
- ODF-P5-05/06/08 — later items in the same confirmed implementation order, not started by this task.
- A real encrypted-file integration test (would require a crypto/OOXML-encryption library this project has no other use for — out of proportion to what ODF-P5-04 actually asks to verify, per Validation above).
