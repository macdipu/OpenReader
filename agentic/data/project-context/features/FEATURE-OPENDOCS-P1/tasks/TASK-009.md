# Engineering Task

## Status
BACKLOG (not started) — split out of TASK-007 on 2026-09-18 by a technical-architecture-planner pass; not a new requirement.

## Story
Open From Other Apps (Android intent-based file opening)

## Objective
ODF-005: let another app (file manager, WhatsApp, email, browser) hand a supported document to OpenDocs via an Android intent, per BRD §7.7.

## Scope
Android `<intent-filter>` registration (`ACTION_VIEW`/`ACTION_SEND`, MIME types for supported categories), a handler that receives the content URI, validates extension/type and readable permission, and — per BRD §7.7 step 4 — opens the correct reader, then records the open in Recents (step 5, reusing `RecentRepository.markOpened`, already implemented).

## Dependencies
**Blocked on at least one document reader existing** (BRD Phase 2/3). `DocumentInteractionController.openDocument()` is currently a stub (`lib/core/presentation/controllers/document_interaction_controller.dart:69-75`) that only shows "reader is not part of this build yet" — there is nothing for an incoming intent to hand off to. BRD §30's own Phase 4 exit criteria ("External-app open scenarios pass") is bundled with delivering the TXT/CSV readers in that same phase, so this task's own natural sequencing already assumes a reader ships first; this dependency is not a new constraint invented for this split, only made explicit.

Also depends on TASK-007's `_verifyStillAccessible` accessibility check (`TECH-SPEC.md`, "TASK-007 planned LLD") — reuse it for the incoming-intent path (step 3, "validate readable permission") rather than re-implementing it.

## Implementation Requirements
Not yet specified. Needs its own `technical-architecture-planner` pass once a reader exists, to decide: intent-filter MIME type list (must match `DocumentCategory.fromExtension`'s supported set), how a URI outside the scanned index (e.g. a WhatsApp download not yet in `documents`) is inserted/indexed before open, and how `android:launchMode="singleTop"` interacts with BRD §12.4's "Incoming intent while another file is open" corner case.

## Acceptance Criteria
TBD — per BRD §28: "Android intent opens correct reader." Cannot be finalized before a reader exists to open.

## Test Requirements
TBD.

## References
- `agentic/data/project-context/features/OpenDocs_BRD_v1.0.md` §7.7 (Open From Other Apps), §12.4 (incoming-intent corner case), §28 (ODF-005), §30 (Phase 4 exit criteria)
- `TECH-SPEC.md` ("TASK-007 planned LLD" — scope finding that split this task out)
- `SRS.md` (Unresolved Specification Questions, #1)

## Out of Scope
Building a reader itself — that is BRD Phase 2/3 scope, tracked elsewhere, not part of this task.
