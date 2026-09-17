# Engineering Task

## Status
DONE (commit `c9faa36`)

## Story
Local Document Index & Scanning

## Objective
Give OpenDocs a persistent, queryable local index of supported documents (ODF-001).

## Scope
`AppDatabase` schema (documents table), `DocumentScannerService.scan()`, `DocumentRepositoryImpl.rescan()`/`getDocuments()`/`countByCategory()`.

## Dependencies
None (first task; establishes the local store everything else reads from).

## Implementation Requirements
- SQLite via `sqflite`, opened lazily, `documents.id = path`.
- Scanner scoped to Download/Documents/DCIM/WhatsApp roots + storage root, depth-capped at 8, extension-based category classification.
- `rescan()` upserts found files and prunes rows for files no longer present, inside one transaction.

## Acceptance Criteria
- After granting storage access and scanning, supported files appear in the index (verified via `flutter run` on a physical device reaching Home without errors — not verified against a populated real file set).
- Re-scanning does not duplicate rows (path is the primary key).
- Unsupported extensions are never indexed (`DocumentCategory.fromExtension` returns `unknown` → skipped).

## Test Requirements
**Not met.** No unit test exercises `DocumentScannerService` or `DocumentRepositoryImpl.rescan()` against a fixture directory. Recommend a `test/` fixture-directory scan test before this task is called release-ready.

## References
- `SRS.md` ODF-001, `TECH-SPEC.md`

## Out of Scope
Android intent-based "Open With" scanning (ODF-005) — that discovers a single file handed to the app, not the bulk index this task builds.
