# ADR-OPENDOCS-storage-access: Android storage-access strategy for local document discovery

## Status
**Accepted.** The user approved this ADR's Decision (2026-09-18), explicitly requesting TASK-007 be unblocked. This approval covers the Decision section as scoped — `MANAGE_EXTERNAL_STORAGE` retained for TASK-007 conditional on mitigation 1 (disclosure screen) — and does not itself resolve the **Open question** below (distribution channel), which the user did not address and which this ADR's own Decision explicitly does not depend on. It also does not constitute a Play Store submission decision; that remains gated on the open question, per Risk 3.

## Context
Phase 1 (`ARCHITECTURE.md`, commit `c9faa36`) shipped `DocumentScannerService` walking local storage with `dart:io` `Directory`/`File` APIs, gated by `StorageAccessService` requesting `MANAGE_EXTERNAL_STORAGE` (with `READ_EXTERNAL_STORAGE` as the pre-Android-13 fallback):

- `DocumentScannerService._rootCandidates` lists `Download`, `Documents`, `DCIM`, and the WhatsApp documents folder, but its last entry is `/storage/emulated/0` itself — so the walk (depth-capped at 8, `lib/services/utilities/document_scanner_service.dart:19-27`) already recurses over the *entire* shared storage tree, not just those four folders. The named folders are redundant with the full-root walk; they exist only as an implementation detail, not a scope limit.
- `documents.id = documents.path` (`SRS.md` "Data Rules"): the absolute filesystem path is the primary key throughout the domain model, repository layer, and SQLite schema. Nothing in the current code carries a content URI or a SAF tree-document identity.
- BRD §7.1 (Local Document Discovery) asks for "documents from user-accessible storage" across arbitrary supported extensions and categories, without restricting *where* in shared storage those documents live — a user's PDFs, DOCX, or spreadsheets could be in any self-created folder, not only the four named above.
- BRD §9.16 (File Information) already lists "Path unavailable due to scoped storage" as an anticipated corner case, so scoped-storage limitations were foreseen but not resolved at BRD time.
- This is a genuine widening of the app's declared privilege versus a typical scoped-storage app: `MANAGE_EXTERNAL_STORAGE` is Android's broadest storage grant, surfaced to the user as an "All files access" toggle in system Settings rather than an in-app runtime dialog, and it is subject to Google Play's Permissions Declaration Form for non-core-file-manager apps (`ARCHITECTURE.md` Risk 1).
- TASK-007 (Open With / Share / File Info / permission-loss robustness) was placed in the Phase 1 backlog specifically because it depends on this decision (`TASK-007.md`: "the ADR on storage-access strategy this depends on").

## Decision
**Keep `MANAGE_EXTERNAL_STORAGE` for now, unchanged, for the scope TASK-007 covers, with three required mitigations before TASK-007 implementation starts:**

1. Add an explicit, prominent in-app disclosure screen shown immediately before the permission request (why the app needs "All files access", named on its own screen, not folded into generic onboarding copy) — Play policy requires this to be "prominent" and it does not exist today; today's onboarding requests the permission without a dedicated explanation step.
2. Keep the primary-key-is-absolute-path design as-is for TASK-007's scope (Share/Open With/File Info/permission re-check) — do not begin a parallel SAF migration inside TASK-007. Mixing partial SAF adoption into a feature-completion task would leave the app in an inconsistent access model with no clear rollback boundary.
3. Record, in the Play Store Permissions Declaration form language (an artifact for whoever manages the store listing, not code), that OpenDocs' core function is local document browsing/management, which is one of Google's own listed acceptable "All files access" use cases (file manager / on-device document management) — the store submission and its justification text are out of scope for this repository and are not authored here.

This decision is **conditional and time-boxed**, not a permanent settlement: it applies only up to and through TASK-007. It does not resolve whether `MANAGE_EXTERNAL_STORAGE` is acceptable for a future Play Store submission — see **Open question** below, which blocks that broader decision.

## Alternatives
1. **`MANAGE_EXTERNAL_STORAGE` (chosen for TASK-007's scope).** Broadest read access; no change to the existing path-keyed data model; matches BRD §7.1's "documents anywhere in user-accessible storage" without restricting discovery to specific folders.
   - Cost: Play Store special-access review; the permission is visible to the user as a system-level "All files access" grant, which reads as higher-risk than a typical app permission even when the underlying use is read-only.
2. **MediaStore-scoped queries** (`MediaStore.Files` on API 29+, no special permission beyond scoped media queries). Avoids the special-access declaration entirely.
   - Cost: `MediaStore.Files` reliably indexes files that were written through MediaStore or that live in a small set of standard public directories; document types outside those directories, or files placed by apps that write directly to the filesystem (a common pattern for PDFs saved from a browser, files moved from a desktop, or files extracted from an archive) are not guaranteed to appear, and this varies by OEM. This would silently under-discover documents relative to what Phase 1 already demonstrates it can find, which is a regression BRD §7.1's acceptance criteria ("user can see supported documents after granting access") would not tolerate without a caveat the BRD does not currently carry.
3. **Storage Access Framework (SAF), `ACTION_OPEN_DOCUMENT_TREE`.** Fully scoped-storage compliant; no special-access declaration; user grants access one directory tree at a time with a persistable URI permission.
   - Cost: this is not a drop-in swap. It replaces `dart:io` absolute paths with `DocumentFile`/content-URI identities end to end — `document_scanner_service.dart`, `documents.id = documents.path` in the schema, every repository, and `DocumentInteractionController`'s path-keyed favorite/recent lookups would all need to carry a URI-based identity instead. It also changes onboarding UX from one settings toggle to a directory-by-directory picker flow (a user with documents scattered across Downloads, a self-made "Docs" folder, and WhatsApp's folder would need to grant three separate tree permissions, and would need to be walked through *why* on first run). That is a data-model and onboarding redesign, not a TASK-007-sized change.
4. **Hybrid (SAF for new content, keep legacy `MANAGE_EXTERNAL_STORAGE`-scanned entries as-is).** Considered and rejected for this ADR's scope: it would require the schema to carry two different identity kinds simultaneously and every consumer to branch on which kind it has, before TASK-007's actual objective (Share/Open With/File Info) is even reached. This is exactly the kind of hierarchy-level decision `technical-architecture-planner` should scope separately if the open question below resolves toward SAF.

## Consequences
- TASK-007 can proceed against the existing path-keyed data model without a parallel migration; Share/Open With/File Info implementation is unblocked once the disclosure screen (mitigation 1) exists.
- The app's declared privilege remains the widest of the three options. Anyone reviewing the manifest, a security audit, or a future contributor should not read the current `MANAGE_EXTERNAL_STORAGE` grant as "settled forever" — it is scoped to the current phase and explicitly reopened by the open question below.
- No code changes are required by this ADR itself. Mitigation 1 (disclosure screen) is new onboarding-flow scope that TASK-007's own technical-architecture-planner pass should size and schedule before Share/Open With/File Info implementation, since Play policy requires it regardless of when the store submission happens.
- Deferring the SAF/MediaStore migration keeps `ARCHITECTURE.md` Risk 1 open rather than closing it; this ADR narrows the risk (documents the reasoning, adds required mitigations) but does not eliminate it.

## Risks
1. **Play Store rejection or extended review remains possible even with mitigation 1.** Google's Permissions Declaration Form review is manual and outcome is not guaranteed by any code or copy change made here; this ADR reduces avoidable rejection reasons but cannot guarantee approval.
2. **The "no parallel SAF migration inside TASK-007" boundary could be violated by scope creep** if Open With/Share implementation discovers it needs URI-based sharing semantics for cross-app compatibility (Android's `FileProvider`/content URIs are the normal mechanism for `Intent.ACTION_SEND` regardless of how the file was discovered). That would need `FileProvider` content URIs for sharing specifically, which is compatible with keeping `dart:io` paths as the discovery/identity mechanism — the two are not the same URI scheme decision, but implementers should not conflate "URI for sharing an already-discovered file" with "URI as the discovery/identity mechanism" (Alternative 3) when scoping TASK-007's Share requirement.
3. **This decision does not survive a change in distribution channel** (see Open question) — if the answer is "internal/sideload only, no Play Store," most of this ADR's caution is moot and `MANAGE_EXTERNAL_STORAGE` carries no store-review risk at all; that would be worth recording as a superseding, simpler ADR rather than carrying this one's conditional language forward.

## Open question (blocks the broader decision; not resolved by this ADR)
**Which distribution channel(s) is OpenDocs targeting, and on what timeline?** This is a business/product decision, not an architectural one, and it is not invented here. It directly determines whether the Play Store Permissions Declaration Form applies at all:
- Play Store, general release → the mitigations above are necessary but the outcome of Google's review is still not guaranteed; a SAF migration (Alternative 3) becomes the durable long-term answer if declarations become a recurring friction point.
- Sideload / internal / F-Droid-style distribution only → the Play Store review risk in `ARCHITECTURE.md` Risk 1 does not apply, and the mitigations above (beyond disclosure, which is good practice regardless) are not required by any store policy.

This ADR's Decision section applies either way for TASK-007's immediate scope, since it does not depend on the answer. The open question should be resolved, by the product owner, before treating `ARCHITECTURE.md` Risk 1 as closed or before scheduling any SAF migration work.

## References
- `ARCHITECTURE.md` (Risk 1, "ADR Recommendation", "Alternatives Considered")
- `SRS.md` (ODF-021/ODF-023 partial status; "Data Rules" — `documents.id = documents.path`)
- `TASK-007.md` (unblocked by this ADR's acceptance)
- `agentic/data/project-context/features/OpenDocs_BRD_v1.0.md` §7.1 (Local Document Discovery), §9.16 (File Information corner cases)
- `lib/services/utilities/document_scanner_service.dart`, `lib/services/utilities/storage_access_service.dart`
- `android/app/src/main/AndroidManifest.xml`
