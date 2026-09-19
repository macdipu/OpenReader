# Engineering Task — TASK-008

## Status
IMPLEMENTED — 33 automated tests pass; static analysis has zero errors/warnings.
Technical scope approved by the user on 2026-09-17; release/UAT approval remains unrecorded.

## Story
Phase 1 Automated Test Coverage

## Request and routing
Continuation requested on 2026-09-17. No midflight task or run existed.
The next task is selected from SPRINT.md, which says coverage should follow TASK-001–006.
Classification: TASK_ONLY; sprint handling: NO_REPLAN.
Preparation run: RUN-0C91C20F214E470D802F0373C10CFFAF (cancelled before command configuration update).
Execution run: RUN-CCCD371EE90E4AEBBE44AC088A869CDE.
The earlier preparation did not constitute approval; the subsequent explicit continuation approved this task scope.

## Objective
Add meaningful regression coverage for local scanning, SQLite repositories, and Home/All Files state rendering before Phase 1 can be considered release-ready.

## Original scoped baseline (before implementation)
Reviewed revision: 70aa685. No root test/ directory exists.
pubspec.yaml provides flutter_test, but no host SQLite test dependency.
The harness doctor passes for its configured local-harness installation; its hooks target Claude, so this Codex session uses the CLI task protocol.
No Flutter checks were executed in this preparation. The harness command allowlist currently has no Flutter checks.
See [TASK-008 baseline](../validation/TASK-008-baseline.md) for source evidence and limitations.

## Implemented plan
1. Add scanner root injection while retaining the singleton and current Android roots for production. Use temporary fixture directories; do not scan personal files.
2. Add an isolated database construction seam that uses the production schema and foreign-key configuration. Use a compatible sqflite_common_ffi development dependency for real host SQLite behavior, with one temporary database per test and explicit teardown.
3. Test the existing repository interfaces against that database. Avoid mocked SQL because it would hide foreign-key and transaction behavior.
4. Add controller/widget fixtures using injected repository and storage-access dependencies. Reset GetX registrations after every test.
5. Reproduce the suspected rescan metadata loss before fixing it. Replace destructive row replacement with update-or-insert behavior that preserves child rows for retained documents; continue pruning records for removed files.
6. Cover loading, empty, populated, denied-access, and failure states on Home and All Files. Fix confirmed state propagation/rendering defects locally, retaining existing layout/components and error conventions. Failed scans must remain visible to the user.
7. Configure the exact Flutter check commands through the supported harness configuration lifecycle before implementation; preserve the recorded run and approval integrity.
8. Run the scoped tests, analyze changed Dart files, and run diff validation. Record exact results and any pre-existing failures. Refresh affected feature context.

## Acceptance criteria
- T008-01: Scanner discovers every supported extension (including uppercase), ignores unknown and zero-byte files, deduplicates overlapping roots, honors the existing depth limit, skips symlinks/missing roots, and leaves fixture bytes unchanged.
- T008-02: Repository tests verify lookup/missing IDs, category counts/filtering, trimmed case-insensitive ordinary-text search, and all six sort modes.
- T008-03: A repeated scan of retained files updates metadata while preserving favorites, recent entries, and reading-position payloads. A removed file is pruned from the index and its dependent rows; tests do not delete files through repository APIs.
- T008-04: Favorites support add/isFavorite/remove/toggle without duplicate entries; recents preserve reading-position JSON, update existing entries, sort by last-opened time, and support remove/clear without deleting indexed documents or favorites.
- T008-05: SQLite failures return the established Failure/Either contract; scan failure does not partially erase an existing index.
- T008-06: Home and All Files visibly distinguish loading, empty, populated, denied-access, and failure states. Home initial load reaches the empty state when all category counts and recents are empty. Repository failure is not silently overwritten by success.
- T008-07: Tests run without Android storage, Firebase, network, personal documents, or time-based sleeps. Test resources and GetX registrations are cleaned up deterministically.
- T008-08: All new tests pass; analysis introduces no diagnostics in changed files; validation and remaining release limitations are recorded.

## Findings reproduced and corrected
- DocumentRepositoryImpl.rescan uses ConflictAlgorithm.replace against documents while AppDatabase enables ON DELETE CASCADE for recents/favorites. The repeated-scan test reproduced lost favorites before the fix. Insert-ignore plus update now preserves retained child rows.
- HomeController.load always sets success after helpers that discard failures, so an empty successful load does not reach HomeView's empty branch.
- HomeView and FilesView have no explicit error-state branch. Both refresh controllers continue into load after a scan failure, which may replace the failure state.

## Scope boundaries
Existing scanner depth and supported extensions remain the contract.
Search wildcard/Unicode semantics, storage-access architecture, full permission-loss recovery, reader implementation, Share/File Info/Open With, and real-device corpus/performance validation remain outside this task.
Unreadable-directory behavior needs a deterministic fixture/fake if host permissions cannot reproduce it; report any unverified case explicitly.
Broader Onboarding/Settings coverage is not claimed by this bounded repository and Home/Files suite.
Unexpected behavior changes beyond the listed corrections return to impact analysis.

## Dependencies and approval
Uses TASK-001 through TASK-006 implementation and existing error/state conventions.
Technical approval: user replied "continue" after being asked to approve this plan and its minimal regression fixes. No UAT or release approval is recorded.

## References
- [TECH-SPEC](../TECH-SPEC.md)
- [SPRINT](../SPRINT.md)
- [SRS](../SRS.md)

## Completion evidence
- [Validation report](../validation/TASK-008-validation.md): acceptance-to-test mapping, environment and limitations.
- [Test result](../validation/TASK-008-tests.json): 33 passing tests.
- [Static analysis](../validation/TASK-008-analysis.json): exit 0, 158 existing informational notices, no errors/warnings.
- [Before-fix reproduction](../validation/TASK-008-rescan-before.json): repeated scan removed a saved favorite.
- Test files: test/services/document_scanner_service_test.dart, test/repositories/document_repositories_test.dart, test/widgets/document_views_test.dart.
- Retry repeats the failed operation: a failed scan retries scanning; a failed load retries loading.

## Resume checkpoint
Implementation and scoped automated verification are complete. Continue this execution run through the remaining human release-readiness gate only when requested/approved; do not recreate or reimplement TASK-008. Phase 1 remains incomplete for TASK-007, storage architecture, device corpus/performance checks, and UAT.
