# Engineering Task

## Status
BACKLOG (not started)

## Story
Share, File Info, Open-With, Permission-Loss Robustness

## Objective
Close the gaps left open in `SRS.md`: ODF-005 (Open With), ODF-009 (Share), ODF-010 (File Information), ODF-021/023 (missing-file / lost-permission handling beyond initial load).

## Scope
New Android intent-filter + handler for ODF-005; wire `DocumentListTile.onShare` to `share_plus` for ODF-009; new File Information screen for ODF-010; a file-existence/permission re-check on document open for ODF-021/023.

## Dependencies
TASK-001 (index), TASK-004 (favorite state pattern to follow for the Share/Info wiring).

## Implementation Requirements
Not yet specified — requires its own `technical-architecture-planner` pass, particularly for ODF-005 (intent-filter shape, MIME type registration) and the ADR on storage-access strategy this depends on (`ARCHITECTURE.md`).

## Acceptance Criteria
TBD — blocked on requirements/architecture work below.

## Test Requirements
TBD.

## References
- `SRS.md` (Unresolved Specification Questions)

## Out of Scope
Nothing yet excluded — scope itself is undecided pending architecture work.
