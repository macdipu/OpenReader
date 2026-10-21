# TASK-008 re-verification baseline — 2026-10-21 (scope revision 1)

## Why
RUN-CCCD371EE90E4AEBBE44AC088A869CDE was BLOCKED at REVIEW (review task interrupted 2026-09-17, marked FAILED 2026-10-21). Its recorded context was STALE: every scope file changed after the original evidence (P2–P5 work, OpenDocs → OpenReader rename, `DocumentScannerService` → `FileScannerService`, feature folder `FEATURE-OPENDOCS-P1` → `FEATURE-OPENREADER-P1`). The user chose "reopen & re-verify"; the run was reopened (intake kept, downstream evidence and approvals revoked).

## Refreshed scope (current names)
`lib/services/utilities/file_scanner_service.dart` (was `document_scanner_service.dart`), `lib/core/data/local/app_database.dart`, document/recent/favorite repository impls, Home and Files controllers/views, `document_load_error_view.dart`, `pubspec.yaml`/`.lock`, and the three TASK-008 test files: `test/services/file_scanner_service_test.dart`, `test/repositories/document_repositories_test.dart`, `test/widgets/document_views_test.dart`.

## Observed results
- `flutter test --reporter expanded`: **140 passed, 0 failed**. The 33 TASK-008 tests are all present and pass: 4 scanner, 14 repository, 15 Home/All Files widget tests. Suite total grew from 33 → 140 through later features.
- `flutter analyze --no-fatal-infos`: **exit 1, 149 issues**. It was exit 0 with 158 infos on 2026-09-17. Visible warnings, all outside TASK-008's test files:
  - `lib/app/shell/app_shell_controller.dart:10` unused import (`app_routes.dart`)
  - `lib/features/settings/presentation/settings_view.dart:441-442` unused optional parameters `destructive`, `busy`
  - The analyzer output was truncated in the agent display (~14.7 KB omitted); whether that hidden section contains any `error`-severity item is **unverified**. 140 compiling/passing tests make errors in test-reachable code unlikely, but this is an inference, not proof.

## Drift from the original acceptance evidence
- T008-01: the original evidence cites a depth 8/9 limit; the current scanner test asserts **no depth limit** (12 levels) after the later "scan-all-storage" change (commit 3a13d40). The criterion text in TASK-008.md is now out of date with intended behavior.
- Widget tests construct `HomeController` without injecting `settingsRepository` (the auto-scan setting added after TASK-008), so the empty-state test exercises the real settings repository.

## Limitations
Host unit/repository/widget verification only. No device, visual, or permission-loss QA. No approval is recorded or implied.
