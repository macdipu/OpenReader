# FEATURE-OPENREADER-P5: Hardening (BRD Phase 5)

## Request and scope

User asked to "Start phase 5" after Phase 4 (Text/CSV readers + Open From Other Apps) shipped and passed verification. This document is a genuine pre-implementation scoping pass, matching P2/P3/P4's own process — no hardening code exists yet.

Unlike P2–P4, Phase 5 is not "build a new reader": BRD §30 lists it as Large-file optimization, Low-memory handling, Security hardening, Corrupted-file handling, Accessibility pass, Performance testing, Offline/network audit, Dependency audit — an audit-and-fix pass against everything already built in Phases 1–4. A dedicated research pass consolidated every already-documented risk/gap from every prior phase's own ARCHITECTURE/TASK docs into `SRS.md`'s Functional Requirements table; nothing there is a newly invented finding.

Classification: proposed grouping of independently shippable hardening items (no cross-item dependency), split into an "actionable now" bucket (code/config fixes verifiable without a device) and a "blocked on environment" bucket (needs a real Android device/emulator, CI, or a large-file test corpus — none of which has existed in any phase of this project).

## Requirements and evidence

| ID | Acceptance criterion | Bucket | Status | Evidence |
|---|---|---|---|---|
| ODF-030 | Remain responsive with large files | Large-file / Performance | NOT VERIFIED, standing gap since P1 | [SRS.md](../project-context/features/FEATURE-OPENREADER-P5/SRS.md) |
| ODF-P5-01 | Stop bundling `.env` as a readable asset | Security | NOT DONE, scoped | Same |
| ODF-P5-02 | Storage-access distribution-channel decision | Security | BLOCKED on product decision | Same |
| ODF-P5-03/04 | Office ZIP/security + corrupted-file hardening | Security / Corrupted-file | NOT DONE, scoped | Same |
| ODF-P5-05 | Offline/network audit | Offline/network | NOT DONE, scoped | Same |
| ODF-P5-06 | Dependency reconciliation | Dependency audit | NOT DONE, scoped | Same |
| ODF-P5-07 | Add CI config | Dependency audit / Security | NOT DONE, scoped | Same |
| ODF-P5-08 | Accessibility semantics baseline | Accessibility | NOT DONE, fresh scope (no prior mention anywhere) | Same |
| ODF-P5-09/10/11 | Large-file corpus, performance profiling, native/device verification | Large-file / Performance | BLOCKED on environment | Same |
| ODF-P5-12 | Low-memory TXT reader tradeoff | Low-memory | Documented, not fixed this pass | Same |

## Design boundaries

No new architectural layer. Every "actionable now" item reuses an existing dependency (Flutter's own `Semantics` API, the already-transitive `archive` package for ZIP-safety checks) or removes a runtime dependency (`flutter_dotenv`, once `.env` moves to compile-time injection) — see `ARCHITECTURE.md` Alternatives Considered. **No new dependency, no ADR** for this phase, same posture P4 took.

`SRS.md`'s Unresolved Question 1 proposes an implementation order for the actionable items (`.env`/CI first, then Office security hardening, then offline audit, dependency reconciliation, and the accessibility pass last as the largest single item) — not yet confirmed.

Three items are explicitly out of this phase's reach rather than silently dropped: ODF-P5-02 (a product decision, not engineering, mirroring the still-open PowerPoint question from `FEATURE-OPENREADER-P3`), and ODF-P5-09/10/11 (large-file corpus, performance profiling, native/device verification — all blocked on an Android SDK/emulator/CI environment that has never existed in this project). `ARCHITECTURE.md` Risks documents what a future device/CI-equipped session would need to actually close these, rather than attempting a lower-fidelity substitute that could be mistaken for real verification.

## Validation and handoff

Scoping confirmed 2026-09-19 — user resolved all four `SRS.md` Unresolved Specification Questions: implementation order accepted as proposed; ODF-P5-02 decided (Play Store, general release, special-access declaration path — recorded in `ADR-OPENREADER-storage-access.md`); ODF-P5-09/10/11 documented-only (no simulated device verification); ODF-P5-08 accessibility baseline confirmed as `Semantics`/`flutter test` coverage. Not yet implemented — ready for task breakdown against the first slice (ODF-P5-01 `.env` fix + ODF-P5-07 CI config).

## Process note

Routed through the same scoping approach as `FEATURE-OPENREADER-P2`/`P3`/`P4` — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
