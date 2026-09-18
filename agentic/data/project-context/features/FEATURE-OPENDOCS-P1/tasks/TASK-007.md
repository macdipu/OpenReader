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
Not yet specified — requires its own `technical-architecture-planner` pass, particularly for ODF-005 (intent-filter shape, MIME type registration). The storage-access ADR this depends on has been drafted: [ADR-OPENDOCS-storage-access](../adr/ADR-OPENDOCS-storage-access.md) (Status: Proposed, not yet approved). It recommends keeping `MANAGE_EXTERNAL_STORAGE` for TASK-007's scope conditional on adding a prominent in-app disclosure screen before the permission request, and leaves an explicit open question (distribution channel) for the product owner. This task remains blocked on that ADR's approval — an unapproved ADR does not authorize starting implementation (per AGENTS.md, artifact creation is not approval).

## Acceptance Criteria
TBD — blocked on ADR approval, then its own requirements/architecture work.

## Test Requirements
TBD.

## References
- `SRS.md` (Unresolved Specification Questions)

## Out of Scope
Nothing yet excluded — scope itself is undecided pending architecture work.
