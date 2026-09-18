# Engineering Task

## Status
IMPLEMENTED (2026-09-18). `flutter analyze`: 0 errors/warnings (158 pre-existing infos, matching TASK-008's baseline). `flutter test`: 50/50 passing (33 pre-existing + 17 new). See `TECH-SPEC.md` → "TASK-007 implementation delta" for what was built, two corrections found during implementation (no manifest FileProvider needed; onboarding disclosure screen already existed), and what remains unverified (no Android SDK/device in this environment — no real build/install/launch, and the accessible/happy path of Share/Open With's native platform integration isn't exercised by the automated tests). No UAT or release approval recorded. ODF-005 was split out to [TASK-009](TASK-009.md) (blocked on a reader existing) — see Scope.

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
From `TECH-SPEC.md` → "TASK-007 planned LLD" → "Acceptance criteria (TASK-007's revised scope)", all met for the parts `flutter analyze`/`flutter test` can verify (native happy-path behavior excepted, see Status):
- ODF-009: Share opens the system share sheet for an accessible file; shows the BRD §13 message instead for a missing/inaccessible one. ✅ guard verified; real share sheet opening is a device-verification item.
- ODF-010: File Information shows path/category/size/modified date; shows "Not available" (not blank or a crash) for created date and reader-derived counts; Share/Favorite/Open With all work from this screen. ✅
- ODF-021/023: open/share/info on a document whose file was deleted or whose permission was revoked after indexing shows the correct BRD §13 message and action, instead of proceeding silently or crashing. ✅
- ADR mitigation: the disclosure screen appears before every `MANAGE_EXTERNAL_STORAGE` request, including a re-request after a prior denial. ✅ (existing screen's copy extended, not a new screen — see TECH-SPEC delta)

## Test Requirements
Implemented in `test/controllers/document_interaction_controller_test.dart` (5), `test/services/file_metadata_service_test.dart` (2), `test/controllers/file_information_controller_test.dart` (4), `test/widgets/document_list_tile_test.dart` (6) — 17 new tests, all passing. See `TECH-SPEC.md` → "TASK-007 implementation delta" for the GetX-snackbar test-draining quirk discovered and worked around while writing these.

## References
- `TECH-SPEC.md` ("TASK-007 planned LLD")
- `SRS.md` (Unresolved Specification Questions)
- `TASK-009.md` (ODF-005, split out of this task)

## Out of Scope
- ODF-005 (Open From Other Apps) — moved to `TASK-009.md`, blocked on a reader existing.
- Reader-derived File Information fields (page/sheet/slide counts) — need a reader's own parser, not available here.
- A parallel SAF storage-access migration — the ADR explicitly excludes this from TASK-007.
