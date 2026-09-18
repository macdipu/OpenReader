# Engineering Task

## Status
READY (unblocked 2026-09-18, not started) — [ADR-OPENDOCS-storage-access](../adr/ADR-OPENDOCS-storage-access.md) is Accepted. Still needs its own `technical-architecture-planner` pass (see Implementation Requirements) before implementation begins; the ADR's approval removes the architecture-decision blocker, not the remaining planning work.

## Story
Share, File Info, Open-With, Permission-Loss Robustness

## Objective
Close the gaps left open in `SRS.md`: ODF-005 (Open With), ODF-009 (Share), ODF-010 (File Information), ODF-021/023 (missing-file / lost-permission handling beyond initial load).

## Scope
New Android intent-filter + handler for ODF-005; wire `DocumentListTile.onShare` to `share_plus` for ODF-009; new File Information screen for ODF-010; a file-existence/permission re-check on document open for ODF-021/023; **plus the ADR's mitigation 1**, a prominent in-app disclosure screen shown before the `MANAGE_EXTERNAL_STORAGE` request (required by the ADR before TASK-007 implementation starts — it does not exist in the current onboarding flow).

## Dependencies
TASK-001 (index), TASK-004 (favorite state pattern to follow for the Share/Info wiring). [ADR-OPENDOCS-storage-access](../adr/ADR-OPENDOCS-storage-access.md) — Accepted, no longer blocking.

## Implementation Requirements
Not yet specified — requires its own `technical-architecture-planner` pass, particularly for ODF-005 (intent-filter shape, MIME type registration) and for sizing/placing the ADR's disclosure-screen mitigation in the onboarding flow. The storage-access decision itself is settled: [ADR-OPENDOCS-storage-access](../adr/ADR-OPENDOCS-storage-access.md) is Accepted — keep `MANAGE_EXTERNAL_STORAGE`, add the disclosure screen, do not begin a parallel SAF migration inside this task. The ADR's open question (distribution channel) is unrelated to starting this task and remains for the product owner separately.

## Acceptance Criteria
TBD — pending the `technical-architecture-planner` pass above; no longer blocked on ADR approval.

## Test Requirements
TBD.

## References
- `SRS.md` (Unresolved Specification Questions)

## Out of Scope
Nothing yet excluded — scope itself is undecided pending architecture work.
