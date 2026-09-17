# TASK-008 scoped baseline — 2026-09-17

Revision: 70aa685. Scope is the existing Phase 1 scanner, database, repositories, and Home/Files screens. No repository-wide audit was performed.

## Observed evidence
- Root directory listing: no test/ directory.
- pubspec.yaml: flutter_test exists; no sqflite_common_ffi dependency.
- lib/services/utilities/document_scanner_service.dart: private singleton, fixed Android roots, depth 8, path deduplication, followLinks false, empty-file filtering.
- lib/core/data/local/app_database.dart: singleton database, foreign keys enabled, cascading recent/favorite relationships.
- lib/core/data/repositories/document_repository_impl.dart: replace inserts during scan, removal pruning in the same transaction, query/filter/sort implementation.
- lib/core/data/repositories/recent_repository_impl.dart: joined history, JSON positions, remove/clear.
- lib/core/data/repositories/favorite_repository_impl.dart: joined favorites and add/remove/toggle.
- lib/features/home/presentation/home_controller.dart: discarded repository failures and unconditional success.
- lib/features/files/presentation/files_controller.dart: load handles failures, but refresh proceeds to load after scan failure.
- lib/features/home/presentation/home_view.dart and lib/features/files/presentation/files_view.dart: loading/empty/access branches exist; no explicit error branch.
- agentic/kit/config/allowed-commands.json: no Flutter command registered.
- Harness doctor: ok, installed for Claude; actual Claude hook invocation and exact preview command remain warnings.

## Coverage map
| Behavior | Existing executable evidence | Planned check |
|---|---|---|
| Discovery/classification/non-destructive traversal | None in host test/ | Temporary file fixtures |
| SQLite search/filter/sort/count | None in host test/ | Real isolated SQLite database |
| Retained metadata across rescans | Source-level risk only | Repeated scan with favorite/recent/position assertions |
| Favorites and recent history lifecycle | None in host test/ | Repository round-trip and isolation assertions |
| Home/Files states and failure propagation | Source inspection only | Injected controller fixtures and widget tests |

## Validation limitations
No Flutter test or analysis command was run. No cascade-loss reproduction was executed.
The code findings are hypotheses or directly observed control-flow omissions, not demonstrated test failures.
Historical analyze/device evidence belongs to the earlier Phase 1 implementation and was not rerun.
The existing runtime-kit tests and plugin example tests do not establish host Phase 1 coverage.

## Next bounded action
After technical approval of TASK-008, establish isolated fixture/database setup, reproduce retained-metadata loss, then implement the specified suite and minimal confirmed corrections. Preserve this run and use the harness lifecycle for configuration changes; do not fabricate approval or bypass the implementation gate.
