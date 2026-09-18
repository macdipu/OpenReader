# ARCH-OPENDOCS-P1: OpenDocs Phase 1 (Foundation)

## Status
Backfilled — describes architecture already implemented at commit `c9faa36`, not a pre-implementation proposal.

## Requirements Covered
ODF-001, ODF-002, ODF-003, ODF-004, ODF-006, ODF-007, ODF-025, ODF-026, ODF-027, ODF-028, ODF-029 (see `SRS.md` for status of each).

## Existing Patterns / Components Reused
Identified before writing new code (per `agentic/data/project-context/modules/app.yaml` and direct inspection of `lib/core`):
- Clean-architecture layering already in place (`core/domain`, `core/data`, `core/presentation`) — new document/recent/favorite domain models and repositories were added *into* this structure, not alongside a new one.
- `BaseController` + `StateStatus` + `runTask`/`Failure`/`Either` error convention — every new controller (`HomeController`, `FilesController`, `FavoritesController`, `RecentsController`) extends `BaseController` and every new repository returns `ResultFuture<T>` via `runTask`, matching `AppSettingsRepositoryImpl` exactly.
- `AppSettingsRepository` (existing) was extended with `hasCompletedOnboarding()`/`setOnboardingComplete()` rather than creating a parallel settings store.
- `PermissionService`/`PathService`/theme system (`ThemeController`, `AppTheme`) reused as-is; Settings screen wraps the existing `ThemeController`, it does not reimplement theming.
- GetX routing/binding conventions (`AppPages`, `Bindings`, `Get.lazyPut(..., fenix: true)`) reused unchanged.

## Component Responsibilities
- `DocumentScannerService` (services/utilities): pure filesystem walk, extension→category classification, no persistence. Bounded to 5 root candidates and depth 8.
- `AppDatabase` (core/data/local): single SQLite connection (lazy singleton), owns schema for `documents`, `recent_documents`, `favorite_documents`.
- `DocumentRepositoryImpl` / `RecentRepositoryImpl` / `FavoriteRepositoryImpl`: own all SQL; nothing above the repository layer knows sqflite exists.
- `DocumentInteractionController` (core/presentation/controllers): the **single** reactive source of truth for favorite state and the single place `openDocument()`/`toggleFavorite()` are implemented, shared by Home/Files/Search/Recents/Favorites so a change on one screen is visible on all others without each screen re-fetching.
- `StorageAccessService`: the only caller of `permission_handler` for storage; `Onboarding`/`Home`/`Files` all go through it rather than calling `Permission.*` directly.
- `AppShellController`: owns bottom-nav tab index and the one piece of cross-tab coordination Phase 1 needed (`openFiles(category:)` so Home's category cards can jump to a filtered Files tab).

## Data / Control Flow
```
DocumentScannerService.scan()  --(List<DocumentModel>)-->  DocumentRepositoryImpl.rescan()
                                                                   |
                                                          upsert + prune (transaction)
                                                                   v
                                                              SQLite: documents
                                                             /            \
                                              RecentRepositoryImpl    FavoriteRepositoryImpl
                                              (recent_documents,      (favorite_documents,
                                               JOIN documents)         JOIN documents)
                                                     |                        |
                                              HomeController /        DocumentInteractionController
                                              RecentsController              |
                                                     \______________________/
                                                                |
                                                        DocumentListTile (shared widget)
```
Onboarding grant → `setOnboardingComplete(true)` + fire-and-forget `rescan()` → `Get.offAllNamed(appShell)`. Home/Files load from the **already-indexed** DB on mount (fast); a full rescan only happens on pull-to-refresh or Settings → "Refresh file index" — the index is never rebuilt just from opening a screen.

## Contracts Affected
New: `DocumentRepository`, `RecentRepository`, `FavoriteRepository` (all under `core/domain/repositories`). Extended: `AppSettingsRepository` (2 new methods). No existing contract's signature changed.

## Failure Handling
Every repository method wraps its body in `runTask`, so a native/database exception becomes a `Failure` (`Either.left`) instead of an uncaught exception — consistent with the rest of the codebase. `SplashController` additionally catches its own bootstrap failure explicitly and still routes to Onboarding rather than leaving the user stuck (BRD 9.1 corner case).

## Security Boundaries
Broad filesystem read access (`MANAGE_EXTERNAL_STORAGE`) is a genuine boundary widening for this app — see **Risks** below. No other privilege was requested. No document content is ever transmitted anywhere; the only I/O added is local file `stat()`/read and local SQLite.

## Alternatives Considered
- **Local store**: SQLite (sqflite) vs. Hive/key-value. Chosen SQLite because BRD §12.3 anticipates 10,000+ indexed files and sortable/filterable queries (`ORDER BY`, `WHERE category=`) — a key-value store would require loading the full index into memory to sort/filter, which doesn't scale the same way.
- **Storage access**: `MANAGE_EXTERNAL_STORAGE` (chosen) vs. MediaStore-scoped queries vs. Storage Access Framework (SAF) directory picker. MANAGE_EXTERNAL_STORAGE was chosen for simplicity of a first pass; it is the **highest-risk** choice of the three (see Risks) and is flagged, not silently settled.

## Migration / Rollback Impact
Additive only — no existing table, route, or repository was removed. Rollback is a plain revert of commit `c9faa36`; the only non-code side effect is the AndroidManifest permission addition, which is also reverted by the same commit revert.

## Risks
1. **`MANAGE_EXTERNAL_STORAGE` is a Play Store "special app access" declaration.** Non-file-manager apps face extra review scrutiny and possible rejection; this is flagged inline in the manifest comment and here, not resolved. An ADR is recommended before this ships to production (see below).
2. Scanner has no total file-count or total size ceiling — only a depth cap. A device with an unusually large `/storage/emulated/0` could make `rescan()` slow; ODF-030 is explicitly unverified.
3. `DocumentInteractionController` is a `fenix: true` lazy singleton scoped to the app-shell route — if a future screen outside the shell needs favorite state, it must go through `Get.find`, not re-fetch independently, or the "single source of truth" property breaks.

## ADR Recommendation
**Drafted**: [ADR-OPENDOCS-storage-access](adr/ADR-OPENDOCS-storage-access.md) (Status: Proposed, not yet approved) compares `MANAGE_EXTERNAL_STORAGE` vs. MediaStore vs. SAF. It recommends keeping `MANAGE_EXTERNAL_STORAGE` conditional on an in-app disclosure screen, and leaves the distribution-channel question (Play Store vs. sideload) open for the product owner — that question, not this ADR, determines whether Risk 1 is fully closed.

## References
- `SRS.md` (this feature)
- `agentic/data/project-context/modules/app.yaml`
- BRD §16 (Local Data Model), §27 (Key Product Risk — informs the SQLite-vs-KV choice by analogy)
