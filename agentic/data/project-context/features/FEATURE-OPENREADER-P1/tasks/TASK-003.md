# Engineering Task

## Status
DONE (commit `c9faa36`)

## Story
Recent History

## Objective
Track which documents were opened and when, for Home's "Continue Reading" and the Recents screen (ODF-006, ODF-008 partial).

## Scope
`recent_documents` table, `RecentRepositoryImpl`, `RecentsController`/`RecentsView`, `HomeController._loadRecents`.

## Dependencies
TASK-001.

## Implementation Requirements
- `markOpened(documentId, readingPosition)` upserts by `document_id`; `readingPosition` stored as JSON, empty map by default.
- Recents screen supports search-within, remove-one, and clear-all with a confirmation dialog ("This will not delete your documents.", BRD 9.9).
- *Later change, pending in CR-OPENREADER-UX Phase 2 (`RUN-F6F654BCBB3742D6A8EF78225881E923`, released in v1.0.4; run still at REVIEW):* `RecentsView` and its route are removed, and `RecentsController` backs Library's History tab, which keeps the same search, remove-one and confirmed clear-all (UX-09).

## Acceptance Criteria
- Opening a document (via `DocumentInteractionController.openDocument`) records it in Recents with a timestamp.
- Clearing Recents removes only DB rows — confirmed by inspection of `RecentRepositoryImpl.clearAll()` (`DELETE FROM recent_documents` only).

## Test Requirements
**Not met.**

## References
- `SRS.md` ODF-006/008

## Out of Scope
Actually restoring a reading position on reopen (ODF-008 completion) — no reader exists yet to read `reading_position` back. This task only builds the storage side.
