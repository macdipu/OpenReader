# TASK-008 validation — 2026-09-17

## Result
33 tests pass: 4 scanner fixture tests, 14 SQLite repository tests, and 15 Home/All Files widget tests. Static analysis exits 0 with no errors or warnings and 158 informational notices in existing code; the two new test lint notices were corrected. git diff --check passes.

Environment: macOS host, repository-pinned Flutter 3.44.4, sqflite_common_ffi 2.3.7+1 and sqlite3 2.9.4. Database files and document fixtures are isolated temporary directories, deleted in teardown. SQLite uses the production schema with foreign keys enabled. Widgets use injected repositories/storage access and reset GetX registrations. No personal documents or network calls are used by the tests.

## Acceptance evidence
| Criteria | Evidence |
|---|---|
| T008-01 | Four scanner tests cover supported/uppercase extensions, metadata, unchanged bytes, zero/unknown files, overlapping roots, missing roots, symlinks, depth 8/9, and deterministic unreadable-directory failure. |
| T008-02 | SQLite lookup, counts, category/search intersection, trimmed ASCII case-insensitive search, query parameterization, and all six sort modes. |
| T008-03 | Repeat scan preserves favorites, recents, timestamps and reading-position JSON while updating document metadata. Removed index rows cascade; fixture file bytes remain unchanged. Favorites survive database reopen. |
| T008-04 | Favorite add/remove/toggle/idempotence/order and recent JSON update/order/remove/clear; recents clearing leaves documents/favorites intact. Ordering uses explicit fixture timestamps, not sleeps. |
| T008-05 | Scanner exception retains the old index; a rejecting SQLite trigger proves transaction rollback; missing foreign keys and a closed database return Failure/Either. |
| T008-06 | Both screens cover loading/empty/populated/denied/failure/retry and retained scan failure. Home history-only failure and nonempty index without recents are covered. Search/filter/sort interaction is exercised. |
| T008-07 | Temporary fixtures, injected platform services, deterministic completion gates, virtual widget timer advancement, and teardown. |
| T008-08 | 33 passing tests, analyzer exit 0, no new diagnostics in changed files in retained analyzer output, and diff check. |

## Regression corrections
The initial SQLite suite had 17 passes and one failure: scanning an existing document removed its saved favorite. The database enabled foreign keys and rescan used REPLACE, deleting/reinserting parent rows. Rescan now inserts missing rows with IGNORE and updates metadata in the same batch/transaction, preserving child rows. This uses SQL supported by older Android SQLite versions without introducing a migration.

Home discarded repository failures and always reported success. It now retains failures and distinguishes an empty index from successful populated content. Both refresh paths stop after scan failure, and a shared inline error widget keeps an error visible with Retry. Retry dispatches to the operation that failed.

The scanner accepts custom roots and AppDatabase accepts a factory/path so tests use production traversal/schema without global platform overrides. Production singleton defaults and schema version remain unchanged.

## Commands and evidence
- flutter test --reporter expanded: [passing output](TASK-008-tests.json).
- flutter analyze --no-fatal-infos: [analysis output](TASK-008-analysis.json). The gateway retains only the tail of long stdout; stderr retains the total count and returncode is 0.
- dart format on the changed existing Dart files and test directory: pass.
- git diff --check: pass.
- [Before-fix SQLite regression](TASK-008-rescan-before.json).

## Review boundaries and remaining work
No new material findings remained after scoped source review. The first widget run encountered a test-fixture compilation error (awaiting Get.reset, which returns void); it was corrected before passing widget verification.
This is local unit/repository/widget verification, not physical-device visual QA, reader validation, full permission-loss recovery, large-corpus performance testing or UAT. Broader Onboarding/Settings coverage is not claimed. No app deployment, commit, push, or release approval is part of this task.

## Harness trace
Preparation RUN-0C91C20F214E470D802F0373C10CFFAF was cancelled with no active worker because command configuration is immutable per run. Execution continues in RUN-CCCD371EE90E4AEBBE44AC088A869CDE with exact Flutter commands registered and the user's technical approval recorded. The first implementation attempt reached its 900-second budget after fixture setup and a confirmed regression; no check was running at the limit. Its failure was recorded and the second bounded attempt continued against refreshed source fingerprints. Start/end/duration and tool evidence are retained by the harness.
