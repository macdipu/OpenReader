# ARCH-OPENREADER-P5: Hardening (BRD Phase 5)

## Status
Draft — scoping only. No new dependency is anticipated for any "Actionable now" item (see Alternatives Considered), so no ADR is expected for this phase either — flagged explicitly, same as `FEATURE-OPENREADER-P4` did for its own no-ADR phase.

## Requirements Covered
ODF-030, ODF-P5-01 through ODF-P5-12 (see `SRS.md`).

## Existing Patterns / Components Reused
- `BaseController`/`StateStatus`/`Failure`/`Either`/`runTask` conventions — unchanged; hardening work fits inside existing controllers rather than adding new architectural layers.
- Every reader's existing error-flow UI (BRD §13's generic messages) — ODF-P5-03/04 aim to make existing fallback paths *correct*, not add new ones.
- `flutter test`'s semantics-tree testing API (`tester.getSemantics`, `matchesSemantics`) — the standard first-party way to verify `Semantics` coverage without a device, proposed for ODF-P5-08's baseline.

## Component Responsibilities (proposed, per actionable item)

### ODF-P5-01 — `.env` packaging
Currently `flutter_dotenv` loads `.env` as a bundled Flutter asset (declared in `pubspec.yaml`'s `assets:`), which ends up readable inside a decompiled APK. Proposed fix: move to compile-time injection via `--dart-define-from-file=env.json` (or per-key `--dart-define`), read through `String.fromEnvironment`, and stop declaring `.env` as an asset. This is a build-config and a handful of call-site changes (wherever `dotenv.env[...]` is currently read), not a new architectural component.

### ODF-P5-03/04 — Office ZIP/security hardening
Add a defensive check before handing file bytes to `docx_file_viewer`/`excel_plus`: read the ZIP central directory (via the already-transitive `archive` package) and reject before full decompression if entry count or uncompressed size exceeds a fixed ceiling (mirrors BRD §13's existing "too large" message, reusing it rather than adding new copy). For ODF-P5-04, add a real encrypted `.docx`/`.xlsx` fixture to the test suite and assert the existing generic corrupted-file path is what actually fires — this is a **verification** task; if it reveals a crash/hang instead, that becomes a real bug fix at that point, not assumed in advance.

### ODF-P5-05 — Offline/network audit
A static trace, not a new component: grep every document-viewer-reachable code path (`lib/features/*_reader`, `lib/core/presentation/controllers/document_interaction_controller.dart`, the file-scanning/repository layer) for any call into `dio`, `firebase_core`/`firebase_messaging`, or `internet_connection_checker_plus`, and confirm (or refute) that none of the three is reachable from those paths. If any of the three's initialization happens unconditionally at app startup (`app_shell_controller.dart`/`main.dart`) rather than being scoped to a genuinely separate feature, document that as a real finding rather than assuming BRD §15 is satisfied by construction.

### ODF-P5-06 — Dependency reconciliation
Not a code component — a documentation-and-decision pass: revisit each already-flagged pin/override (`pdfrx` 2.4.8, `file_picker` local patch, `package_info_plus`/`win32` overrides, `receive_sharing_intent`'s Kotlin 2.4.0 requirement vs. project's 2.2.20) and either (a) confirm the tradeoff is still correct and record why, or (b) resolve it if a low-risk fix exists (e.g. bumping the Kotlin plugin version in `android/settings.gradle.kts` if compatible). Output is an updated `pubspec.yaml`/`android/settings.gradle.kts` plus an updated dependency-audit note in `modules/app.yaml`, not new app code.

### ODF-P5-07 — CI config
A new `.github/workflows/ci.yaml` (or equivalent) running `flutter analyze` and `flutter test` on push/PR. Pure tooling addition, no app-code component.

### ODF-P5-08 — Accessibility pass
Add `Semantics(label: ..., button: ...)` (or use built-in semantics from `IconButton`/`TextButton` where already present but unlabeled) across every interactive control in the 5 reader views plus Home/Recent/Favorites/Settings screens that currently lacks one. Verified via `flutter test`'s semantics matchers, not a new widget layer — existing widgets gain semantics properties, they aren't restructured.

### ODF-P5-12 — Low-memory (TXT reader)
Documented tradeoff, not proposed for a fix in this pass unless the "Actionable now" ordering (`SRS.md` Unresolved Q1) is revised: a truly disk-backed/windowed text decode would require re-architecting `TextReaderController` around chunked file reads instead of one `decodeTextBytes` call, a materially larger change than this phase's other items. Proposed to stay documented-only for now, revisited only if a real large-file corpus (once available) shows it's actually necessary rather than theoretical.

## Data / Control Flow
No new control-flow diagram — every actionable item modifies an existing flow's *robustness*, not its shape:
```
[existing flow, e.g. DocumentInteractionController.openDocument(document) -> reader]
        |
        + ODF-P5-03/04: byte-level guard before Office ZIP parsing, same failure UI on reject
        + ODF-P5-08: Semantics wrapping on the same widgets, no new nodes in the widget tree's logical structure
```

## Contracts Affected
No public method signature changes anticipated. ODF-P5-01 changes *how* config values are obtained (compile-time vs. asset-read) but not the shape callers see. No repository/database contract changes.

## Failure Handling
ODF-P5-03/04 explicitly reuse BRD §13's existing message set ("This document may be damaged or incomplete.", "This document is too large to render safely on this device.") — this phase adds *triggers* for those existing messages in previously-unguarded paths, not new error states.

## Security Boundaries
This phase is substantially *about* security boundaries (ODF-P5-01/02/03/04/05/07) more than any prior phase — treated as the primary lens for this ARCHITECTURE doc rather than an afterthought section, matching BRD §30's explicit "Security hardening" deliverable.

## Alternatives Considered

| Item | Option | Verdict |
|---|---|---|
| `.env` handling | `--dart-define-from-file` (compile-time) | **Proposed.** No new dependency; `flutter_dotenv` is removed as a runtime dependency once call sites migrate. |
| `.env` handling | Keep `flutter_dotenv`, just `.gitignore` harder / obfuscate | **Rejected** — doesn't address the actual finding (readable inside a *built* APK, not the repo). |
| ZIP-bomb guard | Read `archive` package's ZIP central directory metadata before full decompression (already transitive via `docx_file_viewer`/`excel_plus`) | **Proposed.** No new dependency. |
| ZIP-bomb guard | Add a dedicated ZIP-safety package | **Rejected** — `archive`'s own API already exposes what's needed (entry sizes without full extraction); a second package would duplicate capability already present, same "prefer existing implementations" reasoning as every prior phase's library decisions. |
| Accessibility | First-party `Semantics` API + `flutter_test` semantics matchers | **Proposed.** No new dependency; this is Flutter's own built-in mechanism. |
| Accessibility | A third-party a11y-audit package | **Rejected** — no clear gap Flutter's own API doesn't already cover for this project's needs; would be unjustified scope creep for a baseline pass. |

No item in this phase's "Actionable now" bucket requires a new runtime dependency; **no ADR is expected**.

## Migration / Rollback Impact
None to the database. `.env`/CI changes are build-tooling only. Semantics additions and the ZIP-size guard are purely additive and independently revertible per item.

## Risks
1. **ODF-P5-09/10/11 (large-file corpus, performance profiling, native/device verification) cannot be executed in this environment at all** — no Android SDK/emulator/CI has existed in any phase of this project (`modules/app.yaml` known_risks, restated across every phase's own TASK-XXX.md). This ARCHITECTURE doc scopes what a future device/CI-equipped pass would need (a real large-file test corpus per format, an actual Android build, a profiler run against BRD §14's specific numeric targets) but does not attempt a lower-fidelity substitute for any of them.
2. **The offline/network audit (ODF-P5-05) is a point-in-time static trace**, not a runtime network-monitoring capture — a call reachable only through a code path this trace doesn't think to check would be missed. Documented limitation of the proposed method, not assumed exhaustive.
3. **ODF-P5-02 (storage-access distribution channel) has no engineering resolution** — it is gated on a product decision (Play Store vs. sideload) that remains explicitly open, same as PowerPoint's own open question in `FEATURE-OPENREADER-P3`.
4. **The accessibility baseline (ODF-P5-08) is semantics-tree coverage only**, verified without a device — it is not equivalent to an actual screen-reader (TalkBack/VoiceOver) pass, which needs a device and is therefore in the blocked bucket, not this phase's first slice.

## ADR Recommendation
None. Every "Actionable now" item reuses an existing dependency (`archive`, Flutter's own `Semantics`) or removes runtime dependence on one (`flutter_dotenv`) rather than introducing something new — no licensing or alternatives-weighing decision exists to record.

## References
- `SRS.md` (this feature)
- Every prior phase's `ARCHITECTURE.md` Risks/Security Boundaries sections (P1–P4) and `tasks/TASK-XXX.md` — the source of every risk this phase consolidates
- `README.md`, `pubspec.yaml`, `agentic/data/project-context/modules/app.yaml`
- `lib/core/presentation/controllers/document_interaction_controller.dart`, `lib/app/shell/app_shell_controller.dart`, `lib/features/*_reader/presentation/*_controller.dart`
- BRD §12.5, §13, §14, §15, §28 (ODF-029/030), §30 (Phase 5), §31
