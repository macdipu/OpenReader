# Engineering Task

## Status
DONE (implemented, `flutter analyze`/`flutter test` verified) — 2026-09-18. Split out of TASK-007 on 2026-09-18 by a technical-architecture-planner pass; implemented the same day once PDF/Word/Excel/Text/CSV readers all existed to hand off to.

## Story
Open From Other Apps (Android intent-based file opening)

## Objective
ODF-005: let another app (file manager, WhatsApp, email, browser) hand a supported document to OpenDocs via an Android intent, per BRD §7.7.

## Scope
Android `<intent-filter>` registration (`ACTION_VIEW`/`ACTION_SEND`, MIME types for supported categories), a handler that receives the content URI, validates extension/type and readable permission, and — per BRD §7.7 step 4 — opens the correct reader, then records the open in Recents (step 5, reusing `RecentRepository.markOpened`, already implemented).

## Dependencies
Was blocked on at least one document reader existing. Cleared 2026-09-18: `FEATURE-OPENDOCS-P2/tasks/TASK-010.md` (PDF), `FEATURE-OPENDOCS-P3/tasks/TASK-011.md` (Word/Excel), and `FEATURE-OPENDOCS-P4/tasks/TASK-012.md` (Text/CSV) all shipped the same day, unblocking this task for five of six categories. PowerPoint remains without a reader (blocked on its own undecided product question, `FEATURE-OPENDOCS-P3/SRS.md` Unresolved Question 1) and is deliberately excluded from this task's intent-filters (see Implementation Requirements).

Also depended on TASK-007's `_verifyStillAccessible` accessibility check, reused via `DocumentInteractionController.openDocument()` rather than re-implemented.

## Implementation Requirements (as built)
- **Library**: `receive_sharing_intent: ^1.9.0` (Apache-2.0, kasem.dev, ~804 likes/124k downloads at time of research) - handles both `ACTION_VIEW` (Open With) and `ACTION_SEND` (Share sheet), exposes `getInitialMedia()` (cold launch) and `getMediaStream()` (already running, matching `android:launchMode="singleTop"` - already set from TASK-007/008, satisfying BRD §12.4's "incoming intent while another file is open" corner case without further work). No new dependency decision/ADR needed - a standard integration, not a licensing question.
- **A real, verified architectural finding, not assumed**: read the plugin's own Android source (`FileDirectory.kt`) rather than relying on its README. For a `content://` URI from `ExternalStorageProvider`'s "primary" volume (the common "Open with OpenDocs" case from a device's Files app), it resolves to the file's real absolute path under `/storage/emulated/0/...` - the same path `DocumentScannerService` would find. For most other `content://` sources (WhatsApp, Gmail, a third-party file manager's own `FileProvider`), it **copies the shared file into the app's private cache directory** and returns that path instead. Both cases are handled identically by this implementation (indexed and opened the same way); the cache-copy case is flagged as a real, documented interaction with ODF-029 ("Clear app cache safely") below, not silently assumed to always be the original file.
- **A second real finding, verified by reading the schema before writing any code**: `recent_documents.document_id REFERENCES documents(id) ON DELETE CASCADE` with `PRAGMA foreign_keys = ON` (`app_database.dart`). This means a reader's own `markOpened()` call - which every reader in this app makes - would throw a foreign-key-constraint error for a file that was never indexed into `documents`. Indexing before dispatch is therefore mandatory, not a nicety, confirmed rather than assumed. `DocumentRepository.indexDocument(DocumentModel)` was added (a single-row upsert, `ConflictAlgorithm.replace` - unlike `rescan()`, never touches any other row) specifically for this.
- **`IncomingDocumentResolver`** (`lib/services/platform_integration/incoming_document_resolver.dart`): pure logic - extension → `DocumentCategory` (rejecting `unknown` and, deliberately, `powerpoint`, since it has no reader either), `File.stat()` to build a `DocumentModel`, then `DocumentRepository.indexDocument()`. Kept separate from the platform-channel wiring specifically so this decision logic is unit-testable without a real Android intent.
- **`IncomingIntentService`** (`lib/services/platform_integration/incoming_intent_service.dart`): thin wiring - `getInitialMedia()`/`getMediaStream()` → `IncomingDocumentResolver.resolve()` → on success, `DocumentInteractionController.openDocument()` (the same seam every other entry point uses - the reader owns its own `markOpened()`, exactly like TASK-010/011/012's own pattern); on `unsupported`, BRD §13's "Unsupported format" message with an "Open With" action (`OpenFilex.open`); on `inaccessible`, the existing "This file may have been moved or deleted." message. Only the first file of a share is handled (`ACTION_SEND_MULTIPLE` isn't a document use case this app models) - a deliberate scope line, not a silent drop.
- **Wiring**: `AppShellController.onInit()`/`onClose()` start/stop the service. The shell is reached only after onboarding/storage-access is already resolved (even on a cold launch via intent, since `AppPages.initial` is always Splash first), so this is a safe, correct point to start listening.
- **Android manifest**: `MainActivity` gained explicit `ACTION_VIEW` (both `content` and `file` schemes) and `ACTION_SEND` intent-filters for each supported MIME type (PDF, DOC/DOCX, XLS/XLSX, TXT, CSV/CSV-alt) - deliberately **excluding PowerPoint's MIME types**, so Android doesn't offer OpenDocs as a handler for a format it would then have to refuse; that's worse UX than not being a candidate at all. `android:launchMode="singleTop"` was already present from TASK-007/008.

## Implementation delta (2026-09-18)

**A real, bounded testing limitation was found and is being reported precisely, not glossed over.** `IncomingDocumentResolver`'s actual decision logic (category checks, indexing, all three outcomes, case-insensitive extension matching) is fully unit-tested via plain `test()` and passes cleanly (6/6). `IncomingIntentService.handle()`/`.init()`, however, could not be exercised via any `testWidgets` test in this environment: a minimal repro, narrowed across eleven progressively smaller isolated cases (not concluded from a single failure), showed that a `testWidgets` test which both (a) imports anything reaching `document_repository_impl.dart` (i.e. `sqflite` - which any path to `IncomingDocumentResolver` does, since its default constructor references `DocumentRepositoryImpl`) and (b) calls `Directory.systemTemp.createTemp()` anywhere in the same file, hangs `flutter_test`'s own teardown in this Flutter 3.44.4 environment - **regardless of whether either import is actually exercised at runtime, or a fake repository is injected instead of the real one**. This was verified to be a pre-existing environment characteristic, not something this task introduced: it reproduces with `sqflite`/`sqflite_common_ffi` initialized or not, with or without touching the resolver at all, and is unrelated to `receive_sharing_intent`'s own official `setMockValues` test hook (which, used alone with no `sqflite`-touching import in the same file, works perfectly and completes instantly). `handle()` was made `@visibleForTesting` and kept ready to test the moment this environment issue is resolved (e.g., on a real device, in CI with a different Flutter version, or if the root cause is found and fixed) - the design cost of this gap is zero, only its current test coverage is affected.

**The cache-copy path (see Implementation Requirements) is a real, accepted tradeoff, not a hidden one.** A document opened via `ACTION_VIEW`/`ACTION_SEND` from a source other than a device's own Files app (i.e. most real-world sharing - WhatsApp, Gmail, a messaging app) is indexed and read from a copy in OpenDocs' private cache directory, not the original file's location. Consequences, stated plainly: (1) BRD §26 "Never modify original file" still holds - the original is never touched, only read once to make the copy. (2) BRD §29 "Clear app cache safely" can silently invalidate that Recents/Favorites entry - the existing "This file may have been moved or deleted." guard already handles this gracefully (no crash), but the user's reading position for that file is lost when cache clears, which would not happen for a file opened from external storage directly. Not fixed in this task; flagged for a product decision if it matters enough to warrant, e.g., excluding cache-directory documents from Favorites or warning the user.

**Verified, not assumed**: the `.kt` plugin source was read directly to confirm the path-resolution behavior above, and `app_database.dart`'s actual schema was read directly to confirm the foreign-key requirement, rather than inferring either from the plugin's README or guessing at the schema - consistent with this project's established verification standard.

**Not verified, and explicitly flagged as a gap**: real intent delivery from Android itself (an actual "Open with OpenDocs" or "Share" action from another real app, on a real or emulated device) - no Android SDK/emulator is available in this environment, the same posture as every prior native-integration gap in this project (TASK-007's FileProvider merge, TASK-007/008's physical-device verification). The Kotlin plugin's Gradle-declared baseline (`Kotlin 2.4.0`) is also newer than this project's current `org.jetbrains.kotlin.android` version (`2.2.20`, `android/settings.gradle.kts`) - noted here for a real Android build to surface and resolve, not silently assumed compatible.

**Validation:** `flutter analyze`: 0 errors, 0 warnings (158 pre-existing infos - same baseline as every prior task). `flutter test`: 124/124 passing (118 pre-existing + 6 new in `test/services/incoming_document_resolver_test.dart`).

## Acceptance Criteria
Per BRD §28: "Android intent opens correct reader."
- Met and unit-tested for the decision logic: a supported file is indexed and its `DocumentModel` correctly resolved; an unsupported extension or PowerPoint file is rejected without indexing; a missing/unreadable path is reported as inaccessible without indexing.
- Met by construction, not yet device-verified: dispatch to the correct reader reuses `DocumentInteractionController.openDocument()` exactly as every other entry point does, so once a `DocumentModel` is correctly resolved, correct-reader dispatch is the same code path already exercised by TASK-010/011/012's own tests.
- Real Android intent delivery, and the `IncomingIntentService` wiring specifically: unverified in this environment (see delta) - a device-verification item.

## Test Requirements
`test/services/incoming_document_resolver_test.dart` - 6 tests, all passing. `IncomingIntentService` is not covered by an automated test in this environment (see delta for the specific, bounded reason).

## References
- `agentic/data/project-context/features/OpenDocs_BRD_v1.0.md` §7.7 (Open From Other Apps), §12.4 (incoming-intent corner case), §26 (never modify original file), §28 (ODF-005), §29 (clear app cache safely), §30 (Phase 4 exit criteria)
- `FEATURE-OPENDOCS-P2/tasks/TASK-010.md`, `FEATURE-OPENDOCS-P3/tasks/TASK-011.md`, `FEATURE-OPENDOCS-P4/tasks/TASK-012.md` (the readers/dispatch seam this task hands off to)
- `lib/core/data/local/app_database.dart` (the foreign-key finding that made indexing-before-dispatch mandatory)
- `lib/services/platform_integration/` (this task's new code)

## Out of Scope
- Building a reader itself - that was BRD Phase 2/3/4 scope, already done.
- PowerPoint intent-filters/dispatch - excluded per the reasoning above; revisit once a PPTX reader exists.
- Real Android device/emulator verification - see delta.
- Any change to the cache-copy behavior (see delta) - flagged for a product decision, not resolved here.
