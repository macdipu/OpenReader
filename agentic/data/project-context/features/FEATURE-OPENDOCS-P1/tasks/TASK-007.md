# Engineering Task

## Status
READY (technical-architecture-planner pass complete 2026-09-18, not started). [ADR-OPENDOCS-storage-access](../adr/ADR-OPENDOCS-storage-access.md) is Accepted. ODF-005 was split out to [TASK-009](TASK-009.md) (blocked on a reader existing) — see Scope.

## Story
Share, File Information, Open With, Permission-Loss Robustness

## Objective
Close the gaps left open in `SRS.md` that do not require a document reader: ODF-009 (Share), ODF-010 (File Information), ODF-021/023 (missing-file / lost-permission handling beyond initial load), plus the storage-access ADR's required disclosure-screen mitigation. ODF-005 (Open With from another app) is out of scope here — see `TASK-009.md`.

## Scope
See `TECH-SPEC.md` → "TASK-007 planned LLD" for the full design. Summary:
- Wire `DocumentListTile.onShare` to a new `DocumentInteractionController.shareDocument()` (`share_plus`, already a dependency) for ODF-009.
- New File Information screen/route/controller for ODF-010, backed by a new `FileMetadataService` (filesystem `stat()` only, no persistence).
- New `onOpenWith` tile action using Android's `ACTION_VIEW` chooser via a `FileProvider` + a new `open_filex` dependency (not a second ADR — see TECH-SPEC rationale).
- A shared `DocumentInteractionController._verifyStillAccessible()` check (file-exists + permission-still-granted) called before share/info/open-with and at the start of `openDocument()`, for ODF-021/023.
- The ADR's mitigation 1: a prominent in-app disclosure screen in onboarding, shown before `OnboardingController.allowAccess()` requests `MANAGE_EXTERNAL_STORAGE`.

## Dependencies
TASK-001 (index), TASK-004 (favorite-state pattern the Share/Info wiring follows). [ADR-OPENDOCS-storage-access](../adr/ADR-OPENDOCS-storage-access.md) — Accepted, no longer blocking.

## Implementation Requirements
See `TECH-SPEC.md` → "TASK-007 planned LLD" (Reuse map, Share, File Information, Open With, Missing-file/lost-permission robustness, ADR mitigation, Dependencies sections) for the complete design, written 2026-09-18.

## Acceptance Criteria
From `TECH-SPEC.md` → "TASK-007 planned LLD" → "Acceptance criteria (TASK-007's revised scope)":
- ODF-009: Share opens the system share sheet for an accessible file; shows the BRD §13 message instead for a missing/inaccessible one.
- ODF-010: File Information shows path/category/size/modified date; shows "Not available" (not blank or a crash) for created date and reader-derived counts; Share/Favorite/Open With all work from this screen.
- ODF-021/023: open/share/info on a document whose file was deleted or whose permission was revoked after indexing shows the correct BRD §13 message and action, instead of proceeding silently or crashing.
- ADR mitigation: the disclosure screen appears before every `MANAGE_EXTERNAL_STORAGE` request, including a re-request after a prior denial.

## Test Requirements
From `TECH-SPEC.md` → "TASK-007 planned LLD" → "Test Requirements": `_verifyStillAccessible` unit tests (exists+granted / missing / permission-lost), `FileInformationController`/`FileMetadataService` mapping tests including the two explicitly-unavailable fields, and a `DocumentListTile` widget test that Share/Info/Open With menu items appear only when their callback is non-null.

## References
- `TECH-SPEC.md` ("TASK-007 planned LLD")
- `SRS.md` (Unresolved Specification Questions)
- `TASK-009.md` (ODF-005, split out of this task)

## Out of Scope
- ODF-005 (Open From Other Apps) — moved to `TASK-009.md`, blocked on a reader existing.
- Reader-derived File Information fields (page/sheet/slide counts) — need a reader's own parser, not available here.
- A parallel SAF storage-access migration — the ADR explicitly excludes this from TASK-007.
