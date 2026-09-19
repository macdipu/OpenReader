# Engineering Task

## Status
DONE (commit `c9faa36`)

## Story
Favorites

## Objective
Let the user mark/unmark documents as favorites, consistently across every screen (ODF-007).

## Scope
`favorite_documents` table, `FavoriteRepositoryImpl`, `DocumentInteractionController`, `FavoritesController`/`FavoritesView`, `DocumentListTile`'s favorite toggle.

## Dependencies
TASK-001.

## Implementation Requirements
- Single shared `RxSet<String> favoriteIds` in `DocumentInteractionController` — every screen reads/writes through it instead of maintaining its own copy, so toggling on Search immediately reflects on Favorites/Home/Files.
- Optimistic toggle with revert-on-failure.

## Acceptance Criteria
- Favoriting a document on any screen shows it favorited on all others without a manual refresh (`ever(favoriteIds, ...)` reload in `FavoritesController`).
- A failed toggle (repository error) reverts the checkbox/icon state and shows an error.

## Test Requirements
**Not met.** No test verifies the cross-screen reactivity claim above beyond code inspection.

## References
- `SRS.md` ODF-007, `ARCHITECTURE.md` (Component Responsibilities)

## Out of Scope
None within Phase 1.
