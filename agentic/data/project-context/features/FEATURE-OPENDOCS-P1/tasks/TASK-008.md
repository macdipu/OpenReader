# Engineering Task

## Status
BACKLOG (not started)

## Story
Automated Test Coverage

## Objective
Every task above (TASK-001 through TASK-006) shipped with zero automated tests. Close that gap before this phase is called release-ready.

## Scope
Unit tests for `DocumentScannerService` (fixture directory), `DocumentRepositoryImpl`/`RecentRepositoryImpl`/`FavoriteRepositoryImpl` (in-memory or temp-file sqflite), and widget tests for `HomeView`/`FilesView` empty/loading/error states.

## Dependencies
None technically, but should follow directly behind TASK-001–006 rather than being deferred indefinitely.

## Implementation Requirements
Not yet specified.

## Acceptance Criteria
TBD.

## Test Requirements
This task *is* the test requirement for the phase.

## References
- `TECH-SPEC.md` (Test Strategy, Open Decisions)

## Out of Scope
Integration/E2E tests against a real device corpus (BRD §18) — that's QA-phase scope (`automated-qa-agent`, `test-baseline-agent`), not this task.
