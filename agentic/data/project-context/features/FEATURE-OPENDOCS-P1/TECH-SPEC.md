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
- **`DocumentRepositoryImpl.rescan()`**: single `db.transaction` — batch insert-ignore followed by metadata update for every scanned file (TASK-008 correction preserves child rows), then `DELETE FROM documents WHERE path NOT IN (...)` (or delete-all if the scan found nothing) so removed files drop out of the index without touching disk.
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
The initial phase shipped without tests. TASK-008 adds 33 scanner, SQLite repository, and Home/All Files widget tests, all passing on 2026-09-17. Static analysis exits 0 with 158 existing infos and no errors/warnings. See [validation](validation/TASK-008-validation.md).

## Open Decisions
1. TASK-008 closes the bounded scanner/repository/Home/Files test gap; device corpus/performance checks, broader Onboarding/Settings coverage and UAT remain outstanding.
2. Storage-access strategy ADR (carried over from `ARCHITECTURE.md`).
3. Whether `DocumentInteractionController`'s scope (registered only in `AppShellBinding`) is correct long-term, or whether it should move to a global/root binding once a reader route (outside the shell) needs favorite state too.

## References
- `SRS.md`, `ARCHITECTURE.md` (this feature)
- Commit `c9faa36`

## TASK-008 implementation delta
DocumentScannerService supports injected roots; its singleton retains Android defaults. AppDatabase supports an injected DatabaseFactory/path while retaining the production schema and default singleton. Home propagates query/history failures and sets empty only for an empty index and history. Both Home and Files retain rescan failure and expose persistent inline retry; retry repeats the failed operation. A development-only SQLite FFI dependency enables real host database tests.

## TASK-007 planned LLD (technical-architecture-planner pass, 2026-09-18)

### Scope finding: ODF-005 does not fit in TASK-007
BRD §7.7's own "Required Behavior" for ODF-005 (Open From Other Apps) ends at step 4, "Open correct reader," and BRD §30 Phase 4's exit criteria bundles "External-app open scenarios pass" together with delivering the TXT/CSV readers in the same phase — the BRD's own sequencing assumes a reader exists before this ships. Inspecting the current code confirms there is no reader at all: `DocumentInteractionController.openDocument()` (`lib/core/presentation/controllers/document_interaction_controller.dart:69-75`) only calls `markOpened()` and shows "reader is not part of this build yet." An Android intent-filter can be added regardless, but there is nothing for it to correctly hand off to — the acceptance criterion in BRD §28 ("Android intent opens correct reader") cannot be met. This is a material interface gap independent of the storage-access ADR, so per the technical-architecture-planner's readiness boundary it blocks ODF-005 specifically, not the rest of TASK-007.

**Resolution:** ODF-005 is moved out of TASK-007 into [TASK-009](tasks/TASK-009.md), explicitly gated on at least one reader existing. TASK-007 keeps ODF-009 (Share), ODF-010 (File Information), ODF-021/023 (missing-file / lost-permission robustness), and the ADR's disclosure-screen mitigation — none of which need a reader.

### Reuse map
Follows the same patterns `ARCHITECTURE.md` already establishes for this feature: `BaseController`/`Failure`/`Either`/`runTask` for repository-backed work, `DocumentInteractionController` as the single cross-screen source of truth for document actions (extended, not duplicated), GetX routing/binding conventions, and `DocumentListTile`'s existing `onShare`/`onShowInfo` callback slots (declared but never wired by any caller today — confirmed by inspecting `lib/core/presentation/widgets/document/document_list_tile.dart`, which has no `onOpenWith` slot yet either).

### Share (ODF-009)
- Add `DocumentInteractionController.shareDocument(DocumentModel document)`, following the existing `toggleFavorite`/`openDocument` pattern (one controller method, called from every screen's `DocumentListTile.onShare`).
- Uses the already-present `share_plus: ^13.1.0` dependency: `Share.shareXFiles([XFile(document.path)], text: document.displayName)`. No new dependency needed for Share itself.
- Before sharing, run the shared accessibility check below; a missing file or lost permission must not open the share sheet.

### File Information (ODF-010)
- New route (`AppPages`/`GetPage`, `Get.lazyPut(fenix: true)` binding, matching existing route conventions) taking a `DocumentModel` argument, plus a `FileInformationController extends BaseController`.
- Metadata source: a new `FileMetadataService` (pure `dart:io` `FileStat` read, no persistence — same shape as `DocumentScannerService`, not a repository) providing path, extension, category, size, and modified date, all of which `DocumentModel` already carries.
- Two BRD-listed fields are explicitly **not available** rather than guessed: "Created date" (Android's `FileStat.changed` is inode-change time, not creation time — labeling it "created" would be wrong, not merely incomplete) and page/sheet/slide counts (would need format-specific parsing that only a reader has; same root cause as the ODF-005 gap). BRD §9.16 already lists "Metadata unavailable" as an accepted corner case, so surfacing "Not available" for these two fields is within spec, not a scope reduction.
- Actions: Share (reuses `shareDocument`), Favorite toggle (reuses `toggleFavorite`), Open With (below) — matching BRD's File Information "Actions" list exactly.
- Corner case "File deleted after info screen opened": re-run the shared accessibility check when an action button is pressed, rather than adding a file-system watcher (nothing in this codebase does live filesystem watching; checking at point-of-action matches how `rescan()` and onboarding already treat storage state as checked-when-used, not watched).

### Open With (new tile action; BRD Overflow Actions, File Information Actions, and Cross-Format Reader Requirements)
- Distinct from Share: Android's `ACTION_VIEW` chooser hands the file to another app to render it, since OpenDocs has no renderer of its own. This needs a `content://` URI (`file://` is blocked cross-app by `StrictMode` on API 24+), which needs a `FileProvider` declared in `AndroidManifest.xml` plus a `res/xml/file_paths.xml` granting the scanned roots.
- No current dependency does this (`share_plus` only issues `ACTION_SEND`). Recommend adding `open_filex` (wraps exactly this FileProvider + `ACTION_VIEW` + chooser pattern) rather than hand-rolling a platform channel, consistent with "prefer existing implementations" applied at the package level since nothing in-repo does this yet.
- **Not a second ADR:** a `FileProvider` declaration is Android's standard, narrowly-scoped mechanism for this exact use case — additive, not a new service boundary or a reversal of the storage-access decision. Flagged here for traceability since it touches `AndroidManifest.xml` again, not escalated.
- Add an `onOpenWith` callback to `DocumentListTile` alongside the existing `onShare`/`onShowInfo` slots.

### Missing-file / lost-permission robustness (ODF-021/023)
- Add `DocumentInteractionController._verifyStillAccessible(DocumentModel document)`, called before `shareDocument`, before File Information's actions, and at the start of `openDocument` (which still shows its "not implemented" message afterward — this only stops it from claiming success on a file that no longer exists or is no longer reachable):
  - `File(document.path).existsSync()` false → BRD §13 "This file may have been moved or deleted." with "Remove from Recents" wired to the existing `removeFromRecent`.
  - `StorageAccessService.instance.hasAccess()` false → BRD §13 "OpenDocs no longer has access to this file." with "Grant Access" wired to the existing `StorageAccessService.instance.requestAccess()`/`openSettings()`.
- This is the one shared place all three affected flows funnel through, closing the SRS's "no re-check if permission is revoked mid-session" gap without duplicating the check per screen.

### ADR mitigation: disclosure screen
- New screen in the onboarding flow (`lib/features/onboarding/`), shown immediately before `OnboardingController.allowAccess()` requests the permission, explaining why "All Files Access" is needed. Reuses the existing onboarding page-transition mechanism (`smooth_page_indicator`, already a dependency) rather than a new framework.

### Dependencies
Add `open_filex` (or an equivalent FileProvider-based Android `ACTION_VIEW` package) for Open With. Share and File Information need no new package.

### Test Requirements
- `_verifyStillAccessible`: file exists + permission granted → proceeds; file missing → correct BRD §13 message, share sheet/action not invoked; permission lost → correct BRD §13 message. Use dependency injection for the filesystem/permission checks, mirroring TASK-008's injectable-roots pattern for `DocumentScannerService`.
- `FileInformationController`/`FileMetadataService`: metadata maps correctly from a `DocumentModel`; the two explicitly-unavailable fields render as "Not available," not blank or a crash.
- `DocumentListTile` widget test: Share/Info/Open With menu items appear only when their respective callback is non-null (extends the existing widget-test pattern from TASK-008).

### Acceptance criteria (TASK-007's revised scope)
- ODF-009: selecting Share on any screen using `DocumentListTile` opens the system share sheet for that file, unless the file is missing or inaccessible, in which case the BRD §13 message shows instead.
- ODF-010: File Information screen shows path, category, size, modified date for a valid document; shows "Not available" (not blank, not a crash) for created date and reader-derived counts; Share/Favorite/Open With all work from this screen.
- ODF-021/023: opening, sharing, or viewing information for a document whose file was deleted or whose storage permission was revoked after the index was built shows the correct BRD §13 message and offered action, instead of silently proceeding or crashing.
- ADR mitigation: the disclosure screen appears before every `MANAGE_EXTERNAL_STORAGE` request, including a re-request after a prior denial.

## TASK-007 implementation delta (2026-09-18)

Implemented essentially as planned above, with two corrections found only once the actual code/dependency was inspected (both narrow the plan, neither expands scope):

1. **No manifest FileProvider was added.** The chosen dependency, `open_filex: ^4.7.0`, bundles its own `FileProvider` (`android/src/main/AndroidManifest.xml` inside the package, authority `${applicationId}.fileProvider.com.crazecoder.openfile`, `root-path path="."`), merged automatically by Gradle. Declaring a second one in the app's own manifest would have been redundant. Verified no authority collision with `share_plus`'s own bundled provider (`${applicationId}.flutter.share_provider`) by reading both packages' manifests directly. A full Android/Gradle build to observe the actual merged manifest was not run in this environment (no Android SDK installed here) — this is a real, but narrow, unverified boundary; `flutter analyze`/`flutter test` (this project's existing validation bar, per TASK-008) do not touch the Android toolchain at all.
2. **The onboarding disclosure screen already existed.** `onboarding_view.dart` already showed an explanation before the "Allow Access" button, contrary to this document's earlier assumption that no such screen existed. Corrected by extending that existing copy to explicitly name Android's "All Files Access" permission (the specific mechanism Play policy disclosure requirements are about), rather than building a redundant second screen. The re-request-after-denial requirement is satisfied for free, since the same screen/button/copy is what's shown again after a `denied` status.

Everything else matches the plan: `DocumentInteractionController.shareDocument`/`openWithExternalApp`/`_verifyStillAccessible` (using `SharePlus.instance.share(ShareParams(...))` for `share_plus: ^13.1.0`'s actual current API, not the older static `Share.shareXFiles`), `FileMetadataService`, the File Information route/controller/view, and `onOpenWith` on `DocumentListTile`, wired into all five screens that use it (Home, Files, Search, Recents, Favorites).

`CustomSnackbar` gained optional `actionLabel`/`onAction` params (backward compatible) so BRD §13's suggested actions are actually wired to `removeFromRecent`/`requestAccess`, not just described in the message text.

**Validation:** a Flutter 3.44.4 SDK (matching `.fvmrc`) was installed into this environment specifically to run real `flutter analyze`/`flutter test` rather than leaving this code unverified. `flutter analyze`: 0 errors, 0 warnings (158 pre-existing infos, same baseline TASK-008 recorded). `flutter test`: 50/50 passing (33 pre-existing + 17 new: 5 `DocumentInteractionController` guard tests, 2 `FileMetadataService` tests, 4 `FileInformationController` tests, 6 `DocumentListTile` widget tests). The accessible/happy path of `shareDocument`/`openWithExternalApp` (i.e., that the real share sheet/chooser actually opens) is not exercised by these tests — no platform-channel mock is registered for `share_plus`/`open_filex` in this suite, so that native integration remains a device-verification item, consistent with how this project has already treated platform-level checks (see `FEATURE-OPENDOCS-P1.md` "Validation and handoff" for Phase 1's own physical-device verification). No app build/install/launch on a physical or emulated device was performed for this task — no Android SDK/emulator is available in this environment (see correction 1 above); this is a real gap, not elided.

One incidental discovery, worth recording since it will recur: `Get.snackbar`'s combination of a real auto-dismiss `Timer` and an `AnimationController` does not drain cleanly via `tester.pumpAndSettle()` (or a single `pump()` plus manual `Get.closeAllSnackbars()`) in this `get: 4.7.3` / Flutter 3.44.4 pairing — both leave a dangling ticker/timer that fails the test during teardown even when every assertion already passed. A single `tester.pump(const Duration(seconds: 4))` (covering the snackbar's full auto-dismiss duration plus its exit animation) drains it cleanly; that is the pattern used in `test/controllers/document_interaction_controller_test.dart` and should be reused for any future test that triggers a GetX snackbar.
