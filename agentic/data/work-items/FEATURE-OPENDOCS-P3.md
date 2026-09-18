# FEATURE-OPENDOCS-P3: Office Readers (BRD Phase 3)

## Request and scope

User asked to "start scoping Phase 3" as the next step after `FEATURE-OPENDOCS-P2` (PDF reader) shipped and passed verification. This document is a genuine pre-implementation scoping pass, matching P2's own process — no Office-reader code exists yet.

Classification: proposed `STORY_TASK` grouping, same reasoning as P1/P2 (three independently testable readers, large enough to warrant story-level grouping but not yet a committed Sprint Plan). Scope: BRD §30 Phase 3 — DOCX/XLSX/PPTX readers, search within them, reading-state restoration, legacy format support "where feasible."

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-013 | Read DOCX offline | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P3/SRS.md), [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P3/ARCHITECTURE.md) — real library found (`docx_file_viewer`) |
| ODF-014 | Search DOCX text | NOT DONE (scoped) | Same — `docx_file_viewer` has built-in search |
| ODF-015 | Read XLSX offline | NOT DONE (scoped) | Same — `excel_plus` for parsing, first-party grid UI |
| ODF-016 | Search spreadsheet cells | NOT DONE (scoped) | First-party logic over parsed cell data, no library provides it |
| ODF-017 | Read PPTX offline | NOT DONE (scoped) — **library gap, not just unimplemented** | [ARCHITECTURE](../project-context/features/FEATURE-OPENDOCS-P3/ARCHITECTURE.md) Alternatives — no verified free library renders PPTX with real fidelity; needs a product decision (`SRS.md` Unresolved Question 1) before an ADR is even possible |
| ODF-018 | Search slide text | NOT DONE (scoped), blocked on ODF-017 | Same |
| ODF-008 | Restore reading position (Word/Excel/PowerPoint) | NOT DONE (scoped) | [SRS](../project-context/features/FEATURE-OPENDOCS-P3/SRS.md) — no schema migration needed, reuses `RecentRepository.getPosition`/`markOpened` added in `FEATURE-OPENDOCS-P2/TASK-010` |
| n/a | Favorite/Share/Open With/File Info inside each reader | NOT DONE (scoped, low risk) | Reuses `DocumentInteractionController` unchanged, same pattern as the PDF reader |

## Design boundaries

Reuses Phase 1/2's clean-architecture layering, `BaseController`/GetX conventions, and `DocumentInteractionController` wholesale — no reimplementation per reader. `DocumentInteractionController.openDocument()` gains three more category branches (`word`, `excel`, `powerpoint`), the same seam `FEATURE-OPENDOCS-P2` used for `pdf`. `DocumentCategory` already has the right enum values (`word`/`excel`/`powerpoint`) — confirmed by reading `document_category.dart`, no model change needed.

**Library research: done 2026-09-18, partially resolved.** Word and Excel have real, verified, free (MIT/Apache-2.0) library options with no licensing gate to navigate this time — `docx_file_viewer` (native rendering + built-in search) for Word, `excel_plus` (fast, well-adopted parser) plus a first-party grid widget for Excel. [ADR-OPENDOCS-office-libraries](../project-context/features/FEATURE-OPENDOCS-P3/adr/ADR-OPENDOCS-office-libraries.md) records this — **Status: Proposed, not yet approved**.

**PowerPoint is the one real open problem.** No free library found renders PPTX content natively with adequate fidelity — even the strongest actively-maintained multi-format alternative found (`universal_file_viewer`) falls back to opening PPTX in an external app rather than claim inline rendering it can't deliver. This is a verified finding, not a gap in this session's research effort — see `ARCHITECTURE.md` Alternatives for the specific packages checked and why each was insufficient. Three ways forward are laid out in `SRS.md` Unresolved Question 1, none decided here, since it's a product tradeoff (fidelity vs. effort vs. timeline), not an engineering one.

Two other items are explicitly deferred, not silently dropped: legacy binary format support (`.doc`/`.xls`/`.ppt`, BRD §30 says "where feasible," not required) and password-protected Office files (no candidate library's documentation confirms support, unlike PDF's `pdfrx`) — both tracked as `SRS.md` Unresolved Questions 2 and 3.

## Validation and handoff

No implementation code has been written; this pass is research and documentation only, matching how P2's own first scoping pass worked (before the "approve it, start implementation" turn). Next steps, in order:
1. Approve (or amend) `ADR-OPENDOCS-office-libraries.md` for Word and Excel.
2. Decide PPTX's path forward (`SRS.md` Unresolved Question 1) — this blocks writing a PPTX-specific ADR, not the Word/Excel implementation, which can proceed independently.
3. Decide legacy-format and password-flow scope for this phase's first slice (`SRS.md` Unresolved Questions 2–3), or explicitly defer them.
4. Task-breakdown pass once 1–3 are resolved enough to scope concretely — likely Word and Excel as their own tasks (parallel, independent), PowerPoint as a separate task once its path is chosen.

## Process note

Routed through the same scoping approach as `FEATURE-OPENDOCS-P2` and TASK-007's architecture pass — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
