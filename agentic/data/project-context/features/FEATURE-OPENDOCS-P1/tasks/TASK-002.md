# Engineering Task

## Status
DONE (commit `c9faa36`)

## Story
Search, Filter, Sort

## Objective
Let the user narrow the document list by name, category, and order (ODF-002, ODF-003, ODF-004).

## Scope
`FilesController` (category/query/sort state), `SearchDocumentsController` (debounced global search), `_CategoryFilterRow`/sort menu in `FilesView`, `DocumentSortMode` enum.

## Dependencies
TASK-001 (needs the index to query against).

## Implementation Requirements
- Filename match is case-insensitive partial (`LIKE '%query%'`), matching BRD 7.2.
- Sort maps to `ORDER BY` clauses (name/date/size, asc/desc) in `DocumentRepositoryImpl._orderByFor`.
- Global search (separate route) debounces input 250ms before querying.

## Acceptance Criteria
- Typing a partial, mixed-case filename returns matches.
- Selecting a category from Home jumps to the Files tab pre-filtered (`AppShellController.openFiles`).
- Each of the 6 sort modes changes list order.

## Test Requirements
**Not met.** No widget or unit test covers the debounce timing, the SQL `LIKE` matching, or the category-jump interaction.

## References
- `SRS.md` ODF-002/003/004

## Out of Scope
Search *within* a document's content (Reader Search, BRD 9.17) — that requires a reader, which is Phase 2/3.
