# TECH-SPEC-OPENDOCS-P1: OpenDocs Phase 1 (Foundation) — LLD

## Status
Backfilled from commit `c9faa36`.

## Requirement-to-Component Mapping
| Requirement | Component(s) |
|---|---|
| ODF-001 | `DocumentScannerService`, `DocumentRepositoryImpl.rescan()` |
| ODF-002 | `SearchDocumentsController`, `FilesController.setSearchQuery` |
| ODF-003 | `FilesController.selectCategory`, `HomeController.openCategory`, `AppShellController.openFiles` |
| ODF-004 | `DocumentSortMode`, `DocumentRepositoryImpl._orderByFor` |
| ODF-006 | `RecentRepositoryImpl`, `RecentsController`, `HomeController._loadRecents` |
| ODF-007 | `FavoriteRepositoryImpl`, `DocumentInteractionController`, `FavoritesController` |
| ODF-025/026 | `DocumentScannerService` (read-only `stat()`, no writes) |
| ODF-027 | `SettingsController` → existing `ThemeController` |
| ODF-028/029 | `SettingsController.clearRecentHistory` / `.clearCache` |

## LLD / Component Changes
- **`AppDatabase`** (`lib/core/data/local/app_database.dart`): lazy singleton, `openDatabase` v1, `PRAGMA foreign_keys = ON` in `onConfigure`. Three tables: `documents` (PK `id`=path, indexed on `category` and `display_name`), `recent_documents` (PK `document_id`, FK cascade), `favorite_documents` (PK `document_id`, FK cascade).
- **`DocumentScannerService`**: `scan()` walks `_rootCandidates` (Download, Documents, DCIM, WhatsApp Media/WhatsApp Documents, and the storage root as a catch-all) to `_maxDepth = 8`, dedupes by path, classifies by extension via `DocumentCategory.fromExtension`, skips zero-byte files and unreadable directories (logged, not thrown).
- **`DocumentRepositoryImpl.rescan()`**: single `db.transaction` — batch `insert(..., ConflictAlgorithm.replace)` for every scanned file, then `DELETE FROM documents WHERE path NOT IN (...)` (or delete-all if the scan found nothing) so removed files drop out of the index without touching disk.
- **`DocumentInteractionController`**: holds `RxSet<String> favoriteIds` as the shared favorite-state source; `toggleFavorite` is optimistic (mutates the set immediately, reverts + snackbars on repository failure). `FavoritesController` subscribes via `ever(favoriteIds, ...)` to reload its own list when any screen toggles a favorite.
- **`SplashController`**: opens `AppDatabase.instance.database` (creates schema on first run) then checks `AppSettingsRepository.hasCompletedOnboarding()`; any exception during this is caught and treated as "not onboarded" rather than propagated.
- **`OnboardingController`**: `allowAccess()` requests `manageExternalStorage` then falls back to `storage`; on grant, marks onboarding complete and fires `rescan()` unawaited (BRD 9.2 shouldn't block the transition to Home on the first scan finishing).

## API Contracts
No remote API contracts — this phase adds none, per BRD §15 (offline mandatory). Internal Dart contracts are the three repository interfaces listed in `ARCHITECTURE.md`.

## Database Impact
New local schema only (see above); no migration path was needed since `documents`/`recent_documents`/`favorite_documents` are new tables at schema version 1. A future schema change must bump `AppDatabase._version` and add an `onUpgrade` — none exists yet because there has been no prior version to migrate from.

## Security
`android/app/src/main/AndroidManifest.xml` gained `READ_EXTERNAL_STORAGE` (maxSdk 32) and `MANAGE_EXTERNAL_STORAGE` (`tools:ignore="ScopedStorage"`). This is the single security-relevant change in this phase — see `ARCHITECTURE.md` Risk 1 and the pending ADR.

## Error Handling
All repository calls return `Either<Failure, T>` via `runTask`; controllers use `BaseController.handleFailure` (sets `StateStatus.error`, shows a snackbar) or fold explicitly where a specific UI reaction is needed (e.g., favorite-toggle revert).

## Observability
None added. `AppLogger` is used for scan-time warnings (unreadable file/directory) only; there is no structured event for rescan duration or document counts. Flagged as a gap, not solved here.

## Dependencies
Added to `pubspec.yaml`: `sqflite: ^2.4.1`, `path: ^1.9.0` (both were already present transitively at the versions pinned; `pub get` resolved instantly, no version bump risk).

## Migration / Configuration Impact
None beyond the manifest permission addition above.

## Compatibility / Rollback
Purely additive; revert `c9faa36` to roll back completely (see `ARCHITECTURE.md`).

## Test Strategy
**Not executed as part of this phase.** `flutter analyze` is clean (0 errors/warnings introduced). No unit tests were written for the new repositories/controllers, and no widget tests exist for the new screens. This is the single largest gap in this backfill — see Open Decisions.

## Open Decisions
1. No automated test coverage exists for `DocumentRepositoryImpl`, `DocumentScannerService`, or any controller. `automated-qa-agent`/`test-baseline-agent` should run before this phase is called release-ready.
2. Storage-access strategy ADR (carried over from `ARCHITECTURE.md`).
3. Whether `DocumentInteractionController`'s scope (registered only in `AppShellBinding`) is correct long-term, or whether it should move to a global/root binding once a reader route (outside the shell) needs favorite state too.

## References
- `SRS.md`, `ARCHITECTURE.md` (this feature)
- Commit `c9faa36`
