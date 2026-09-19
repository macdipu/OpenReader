# SRS-OPENREADER-P5: Hardening (BRD Phase 5)

## Status
Ready for implementation — scoping confirmed 2026-09-19 (all four Unresolved Specification Questions below resolved by the user). No implementation exists yet.

## Scope
BRD §30 Phase 5: Large-file optimization, Low-memory handling, Security hardening, Corrupted-file handling, Accessibility pass, Performance testing, Offline/network audit, Dependency audit.

Unlike Phases 2–4, this phase is not "build a new reader" — Phases 1–4 (all five reader categories except PowerPoint, Share/File Info/Open With, Open From Other Apps) already shipped. Phase 5 is audit-and-fix against BRD's own 8 named categories. Every item below is pulled from a specific existing doc (task/architecture docs from P1–P4, README, pubspec.yaml, `modules/app.yaml`), consolidated here for the first time — nothing in this SRS is a newly invented risk.

This scoping pass also splits every item by feasibility, because one constraint has been reconfirmed in every prior phase and doesn't go away for this one: **no Android SDK/emulator and no CI exist in this environment**, and no large-file test corpus has ever been assembled. Two buckets result:
- **Actionable now**: code/config-level fixes verifiable via `flutter analyze`/`flutter test` or direct source inspection, with no device/CI dependency.
- **Blocked on environment**: needs a real device, CI, or an actual large-file corpus that doesn't exist in this sandbox. These are scoped and documented as explicitly deferred (same posture P1–P4 already took for their own device/performance gaps), not silently dropped from BRD's exit criteria.

## Actors / Roles
Same single actor (device owner, offline, no accounts) for runtime-facing items. This is the first phase where the release/build pipeline itself is also in scope (the `.env`-packaging and dependency-audit items have no runtime "actor" at all).

## Functional Requirements
IDs reused from the BRD Requirement Traceability Matrix (§28) where they exist (ODF-030 is Phase 5's only itemized BRD requirement); new `ODF-P5-xx` IDs added for the concrete, already-documented gaps this phase consolidates.

| ID | Requirement | Bucket | Status | Source |
|---|---|---|---|---|
| ODF-030 | Remain responsive with large files (UI tested against a corpus) | Large-file / Performance | NOT VERIFIED — no test corpus ever assembled, same gap since P1 | `FEATURE-OPENREADER-P1/ARCHITECTURE.md` Risk 2, carried forward by every later phase's own ARCHITECTURE.md Risks |
| ODF-P5-01 | Stop bundling `.env` as a readable Flutter asset in release builds | Security | DONE (2026-09-19) — compile-time constants, `flutter_dotenv` removed | commit `2aeae27` |
| ODF-P5-02 | Record a distribution-channel decision for `MANAGE_EXTERNAL_STORAGE` (Play Store "special access" declaration vs. sideload) | Security | DECIDED 2026-09-19 — Play Store, general release, special-access declaration path | `ADR-OPENREADER-storage-access.md`, `FEATURE-OPENREADER-P1/ARCHITECTURE.md` Risk 1 |
| ODF-P5-03 | Add a defensive ceiling (entry count / uncompressed-size) before parsing DOCX/XLSX ZIP containers | Security / Corrupted-file | DONE (2026-09-19) — `ZipSafetyGuard`, wired into both Office readers | [TASK-015.md](tasks/TASK-015.md) |
| ODF-P5-04 | Verify a password-protected Word/Excel file fails gracefully (existing generic corrupted-file message), not with a crash or hang | Security / Corrupted-file | DONE (2026-09-19) — verified via an OLE2-compound-file fixture (see TASK-015 Validation for why this suffices without real encryption) | [TASK-015.md](tasks/TASK-015.md) |
| ODF-P5-05 | Audit whether any bundled dependency (`dio`, `firebase_core`, `firebase_messaging`, `internet_connection_checker_plus`) is reachable from a document-viewer code path in violation of BRD §15's offline mandate | Offline/network | NOT DONE — offline posture verified "by inspection" only per phase, never audited project-wide in one pass | `FEATURE-OPENREADER-P1/SRS.md` NFR, `FEATURE-OPENREADER-P3/SRS.md` NFR, `pubspec.yaml` |
| ODF-P5-06 | Reconcile flagged dependency-audit items: `pdfrx` version pin (missing 2.5.0+ fixes, blocked on Flutter SDK bump), the local `file_picker` patch/override, the `receive_sharing_intent` Kotlin-version mismatch (2.4.0 required vs. project's 2.2.20), `docx_file_viewer`'s low-adoption/bus-factor risk | Dependency audit | NOT DONE, each individually documented but never revisited together | `FEATURE-OPENREADER-P2/ARCHITECTURE.md` Risk 1, `FEATURE-OPENREADER-P3/ARCHITECTURE.md` Risk 4, `FEATURE-OPENREADER-P1/tasks/TASK-009.md` delta, `pubspec.yaml` |
| ODF-P5-07 | Add a CI config (currently none — `.github` absent) so `flutter analyze`/`flutter test` run automatically instead of only ever being run manually in this session | Dependency audit / Security | DONE (2026-09-19) — `.github/workflows/ci.yml` | `TASK-013.md` |
| ODF-P5-08 | Accessibility pass: semantics labels for reader controls (search, zoom, page/sheet/slide navigation, favorite/share/open-with), screen-reader behavior, text scaling, contrast | Accessibility | NOT DONE — **zero mentions found anywhere in P1–P4 docs**; this is fresh scope, not a consolidation of an existing gap | This SRS (new finding — confirmed absent by a full pass over every phase's ARCHITECTURE/TASK docs) |
| ODF-P5-09 | Verify TXT/CSV's shipped hard size-ceiling-and-refuse strategy (not streaming/windowed reading) against a real large-file corpus, and reconsider PDF/Office readers' own unverified large-document behavior (5,000+ page PDF, 100,000+ row XLSX, 500+ slide PPTX) | Large-file | BLOCKED on environment — no corpus, no device | `FEATURE-OPENREADER-P4/ARCHITECTURE.md` Risk 1, `FEATURE-OPENREADER-P2/ARCHITECTURE.md` Risk 2, `FEATURE-OPENREADER-P3/ARCHITECTURE.md` Risk 6 |
| ODF-P5-10 | Profile BRD §14 performance targets (cold start <2s, indexed Home load <1s, small PDF open <2s, 60fps scrolling) against a real build | Performance | BLOCKED on environment — no device/emulator has existed in any phase of this project | `FEATURE-OPENREADER-P1/SRS.md` NFR, restated verbatim in every later phase's SRS as a standing unresolved item |
| ODF-P5-11 | Native rendering verification (PDFium via `pdfrx`, `docx_file_viewer`'s widget rendering) and real Android intent delivery (TASK-009) on an actual device | Performance / Security | BLOCKED on environment | `FEATURE-OPENREADER-P2/tasks/TASK-010.md` delta, `FEATURE-OPENREADER-P1/tasks/TASK-009.md` delta |
| ODF-P5-12 | Low-memory: TXT reader's `ListView.builder` virtualizes the widget tree but still holds the whole decoded string in memory; no disk-backed/windowed decode path for any reader | Low-memory | NOT DONE, documented tradeoff | `FEATURE-OPENREADER-P4/tasks/TASK-012.md` delta |

## Non-Functional Requirements
- BRD §14's performance targets apply to every reader built so far; none has ever been measured against a real device (ODF-P5-10/11) — restated once here as the standing item it already is, not re-derived.
- BRD §15's offline mandate has been asserted per-phase by design inspection only; ODF-P5-05 is the first attempt at an actual project-wide audit rather than a per-feature assertion.
- BRD §12.5's security corner cases (malformed document, ZIP bomb, path traversal, unsupported encryption) have been *named* as risks in every Office/PDF phase's ARCHITECTURE.md but never *audited* — ODF-P5-03/04 are the first attempt to close that gap with real (if partial) work rather than another restatement.

## Data Rules
No schema change anticipated for any actionable item. ODF-P5-01 (`.env` packaging) is a build-config change (`--dart-define-from-file` or equivalent), not an app-data change. ODF-P5-08 (accessibility) is additive `Semantics`/`ExcludeSemantics` wrapping on existing widgets, no model change.

## Interfaces
- No new reader routes or `DocumentInteractionController` branches — this phase touches existing code paths (Office parsing entry points, network-capable dependencies, reader widget trees) rather than adding new ones.
- `pubspec.yaml`/CI config changes (ODF-P5-06/07) are build-tooling, not app interfaces.

## Flows
### Normal Flow
No new user-facing flow. Where an actionable item changes behavior (e.g. a password-protected Office file now fails predictably instead of an unverified fallback), the existing error-flow UI (BRD §13's generic messages) is reused, not replaced.

### Error Flows
ODF-P5-03/04 aim to convert *unverified* corrupted-file/security fallback behavior into *verified* fallback behavior using BRD §13's existing message set — no new error copy is proposed unless implementation reveals a gap BRD's existing table doesn't cover.

## Traceability
See the Functional Requirements table above.

## Unresolved Specification Questions (resolved 2026-09-19)
1. **Which "Actionable now" items should this phase's first implementation slice include?** RESOLVED — proposed order confirmed as-is: (a) ODF-P5-01 `.env` fix and ODF-P5-07 CI config, both small and high-value; (b) ODF-P5-03/04 Office security/corrupted-file hardening, since BRD §12.5 flags them explicitly by name; (c) ODF-P5-05 offline/network audit; (d) ODF-P5-06 dependency reconciliation; (e) ODF-P5-08 accessibility pass, the largest single item.
2. **ODF-P5-02 (storage-access distribution channel) is a product decision, not engineering work.** RESOLVED — user decided: Play Store, general release, using the special-access declaration path (not sideload, not a scoped-storage/SAF rework). Recorded in `FEATURE-OPENREADER-P1/adr/ADR-OPENREADER-storage-access.md` Open question. This does not resolve the still-open PowerPoint question (`FEATURE-OPENREADER-P3/SRS.md` Unresolved Q1), which remains a separate, undecided item.
3. **ODF-P5-09/10/11 (large-file corpus, performance profiling, native/device verification) cannot be completed in this environment at all.** RESOLVED — confirmed: document the concrete steps a future device/CI-equipped session would need to run (see `ARCHITECTURE.md` Risks); do not attempt a lower-fidelity substitute (e.g. manual code-reading "as if" review) that could be mistaken for real verification.
4. **Depth of the accessibility pass (ODF-P5-08).** RESOLVED — confirmed baseline: Flutter's own `Semantics` widget coverage for every interactive control across all 5 readers plus Home/Recent/Favorites/Settings, verified via `flutter test`'s semantics-tree assertions (no device/screen-reader needed for this slice). A full manual TalkBack/VoiceOver pass remains deferred into Question 3's device-blocked bucket.

## References
- `agentic/data/project-context/features/OpenReader_BRD_v1.0.md` §12.5, §13, §14, §15, §28 (ODF-029/030), §30 (Phase 5), §31
- Every prior phase's `ARCHITECTURE.md` Risks section and `tasks/TASK-XXX.md` implementation-delta docs (P1: TASK-007/008/009; P2: TASK-010; P3: TASK-011; P4: TASK-012) — the actual source of every item in the Functional Requirements table
- `agentic/data/project-context/modules/app.yaml` (known_risks), `README.md`, `pubspec.yaml`
- `FEATURE-OPENREADER-P1/adr/ADR-OPENREADER-storage-access.md`, `FEATURE-OPENREADER-P2/adr/ADR-OPENREADER-pdf-library.md`, `FEATURE-OPENREADER-P3/adr/ADR-OPENREADER-office-libraries.md`
