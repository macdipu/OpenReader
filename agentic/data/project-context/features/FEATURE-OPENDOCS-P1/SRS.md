# SRS-OPENDOCS-P1: OpenDocs Phase 1 (Foundation)

## Status
Backfilled (implementation already merged at `c9faa36`, commit history `4325567..c9faa36`). This document was generated *after* code, not before — treat "Traceability" as a verification record, not a pre-implementation approval.

## Scope
BRD v1.0 §30 Phase 1 (Foundation): local document discovery/index, storage-access permission flow, and the non-reader shell screens (Home, All Files, Search, Recents, Favorites, Settings). Excludes all reader screens (BRD §9.10–9.17), which are Phase 2/3.

## Actors / Roles
Single actor: the device owner using OpenDocs locally. No accounts, no roles, no remote actors (BRD §3 — non-goal).

## Functional Requirements
Stable IDs reused from the BRD Requirement Traceability Matrix (§28) rather than invented in parallel.

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| ODF-001 | Discover supported local documents | **DONE** | `DocumentScannerService` walks Download/Documents/DCIM/WhatsApp roots; `DocumentRepositoryImpl.rescan()` persists to SQLite |
| ODF-002 | Search files by filename | **DONE** | `SearchDocumentsController` (debounced `LIKE` query); All Files search-within field |
| ODF-003 | Filter by document category | **DONE** | `FilesController.selectCategory`, Home category cards |
| ODF-004 | Sort files | **DONE** | `DocumentSortMode` (6 modes), `FilesView` sort menu |
| ODF-005 | Open document from another app (Android intent) | **NOT DONE** | No intent-filter wired; BRD assigns this to Phase 4 (§30) |
| ODF-006 | Maintain Recents | **DONE** | `recent_documents` table, `RecentRepositoryImpl`, Recents screen (BRD 9.9) |
| ODF-007 | Maintain Favorites | **DONE** | `favorite_documents` table, `FavoriteRepositoryImpl`, Favorites tab, shared `DocumentInteractionController` |
| ODF-008 | Restore reading position | **PARTIAL** | Schema has `reading_position` JSON column and `markOpened()` accepts it; nothing writes a real position yet because no reader exists to produce one |
| ODF-009 | Share original document | **NOT DONE** | `DocumentListTile.onShare` hook exists but is never wired to `share_plus` |
| ODF-010 | Display file metadata | **NOT DONE** | File Information screen (BRD 9.16) not built; not in Phase 1 deliverable list (§30) |
| ODF-021 | Handle missing file | **PARTIAL** | No explicit "file no longer exists" check on tap; a deleted file would fail silently on open (untested — no reader exists to surface the failure) |
| ODF-023 | Handle lost permission | **PARTIAL** | Home/Files show a permission banner when access is missing at *screen load*; no re-check if permission is revoked mid-session |
| ODF-025 | Keep user content local / offline | **DONE** | No network calls added; scanner/DB/repositories are 100% on-device |
| ODF-026 | Never modify original file | **DONE** | Scanner only reads `stat()`; no write/delete path touches a discovered file |
| ODF-027 | Dark/Light/System theme | **DONE** | Pre-existing `ThemeController`/`AppSettingsRepository`, wired into Settings UI |
| ODF-028 | Clear Recents without deleting files | **DONE** | `RecentRepository.clearAll()` only deletes DB rows |
| ODF-029 | Clear app cache safely | **DONE** | `SettingsController.clearCache()` clears temp dir only |
| ODF-030 | Remain responsive with large files | **UNVERIFIED** | No test corpus run (BRD §18); scanner has a depth cap (8) but no file-count/size ceiling |

Out of scope for this SRS: ODF-011 through ODF-020 (all reader-screen requirements) — no reader exists yet.

## Non-Functional Requirements
- Offline-only: confirmed by inspection — no new dependency in this change performs network I/O (BRD §15).
- BRD §14 performance targets (cold start <2s, indexed Home load <1s) were **not measured**; no profiling was run against this build.

## Data Rules
- `documents.id = documents.path` (filesystem path is the natural key; re-scanning replaces by path, never duplicates).
- `recent_documents` and `favorite_documents` both `REFERENCES documents(id) ON DELETE CASCADE` — removing a document from the index removes its recent/favorite rows too (requires `PRAGMA foreign_keys = ON`, set in `AppDatabase._open`).
- Category is derived purely from file extension (`DocumentCategory.fromExtension`); a `.pdf` file with corrupted content is still indexed as `pdf` — no content sniffing.

## Interfaces
- `DocumentRepository`, `RecentRepository`, `FavoriteRepository` (domain contracts) — the only interfaces a future reader or Phase 2/3 screen should depend on, not `AppDatabase` directly.
- `StorageAccessService` — the only permission surface; no other code should call `permission_handler` directly for storage.

## Flows
### Normal Flow
Splash → (first run) Onboarding → Allow Access → scan → App Shell (Home). Returning user: Splash → App Shell directly (BRD 9.1 Scenario B).

### Alternate Flows
Onboarding "Not Now" → App Shell in limited mode with a permission banner instead of a document list (BRD 9.2 Scenario B).

### Error Flows
- Splash's local-init failure (DB open throws) is caught and falls back to Onboarding rather than blocking (BRD 9.1 "never block permanently on splash").
- Storage permanently denied → Onboarding shows an "Open Settings" path (BRD 9.2 Scenario C).
- Favorite toggle failure reverts the optimistic UI update and shows an error snackbar.

## Traceability
See the Functional Requirements table above — each row already carries `ID → status → evidence`, which doubles as the source-to-acceptance-criteria trace this section would otherwise repeat.

## Unresolved Specification Questions
1. ODF-005 (Open From Other Apps): resolved as **blocked, not merely undecided** by the 2026-09-18 technical-architecture-planner pass (`TECH-SPEC.md` "TASK-007 planned LLD") — `DocumentInteractionController.openDocument()` is a stub with no reader to hand an incoming intent off to, matching BRD §30's own Phase 4 bundling of "External-app open" with the TXT/CSV readers. Tracked as `TASK-009.md`, gated on a reader existing, not on a technical-architecture-planner pass alone.
2. ODF-010 (File Information): resolved by the same pass — screen/route/controller design is in `TECH-SPEC.md` "TASK-007 planned LLD"; tracked as `TASK-007.md`, pulled into this phase's follow-up work ahead of BRD's Phase 4.
3. Whether "large file" (ODF-030) means scan-time (thousands of files) or reader-time (one huge PDF) is undecided — BRD §12.3/§14 imply both; Phase 1 only touches the scan-time case, and it is unverified even there.

## References
- `agentic/data/project-context/features/OpenDocs_BRD_v1.0.md` §7, §9.3–9.9, §9.18, §16, §28, §30
- Commit `c9faa36` (implementation)
