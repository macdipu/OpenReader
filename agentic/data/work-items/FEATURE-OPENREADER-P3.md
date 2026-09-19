# FEATURE-OPENREADER-P3: Office Readers (BRD Phase 3)

## Request and scope

User asked to "start scoping Phase 3" as the next step after `FEATURE-OPENREADER-P2` (PDF reader) shipped and passed verification. This document is a genuine pre-implementation scoping pass, matching P2's own process — no Office-reader code exists yet.

Classification: proposed `STORY_TASK` grouping, same reasoning as P1/P2 (three independently testable readers, large enough to warrant story-level grouping but not yet a committed Sprint Plan). Scope: BRD §30 Phase 3 — DOCX/XLSX/PPTX readers, search within them, reading-state restoration, legacy format support "where feasible."

## Requirements and evidence

| ID | Acceptance criterion | Status | Evidence |
|---|---|---|---|
| ODF-013 | Read DOCX offline | DONE, test-verified (real-file round trip) | [TASK-011](../project-context/features/FEATURE-OPENREADER-P3/tasks/TASK-011.md) |
| ODF-014 | Search DOCX text | DONE | Same — `docx_file_viewer`'s built-in search, wired to the reader's app bar |
| ODF-015 | Read XLSX offline | DONE, test-verified (real-file round trip) | Same — `excel_plus` for parsing, first-party grid UI |
| ODF-016 | Search spreadsheet cells | DONE | First-party logic over parsed cell data, test-verified |
| ODF-017 | Read PPTX offline | NOT DONE (scoped) — **library gap, not just unimplemented** | [ARCHITECTURE](../project-context/features/FEATURE-OPENREADER-P3/ARCHITECTURE.md) Alternatives — no verified free library renders PPTX with real fidelity; needs a product decision (`SRS.md` Unresolved Question 1) before an ADR is even possible |
| ODF-018 | Search slide text | NOT DONE (scoped), blocked on ODF-017 | Same |
| ODF-008 | Restore reading position (Word/Excel/PowerPoint) | DONE for Excel; **write-only, no restore** for Word (real library gap — see TASK-011); n/a for PowerPoint (not built) | [TASK-011](../project-context/features/FEATURE-OPENREADER-P3/tasks/TASK-011.md) |
| n/a | Favorite/Share/Open With/File Info inside each reader | DONE for Word/Excel | Reuses `DocumentInteractionController` unchanged, same pattern as the PDF reader |

## Design boundaries

Reuses Phase 1/2's clean-architecture layering, `BaseController`/GetX conventions, and `DocumentInteractionController` wholesale — no reimplementation per reader. `DocumentInteractionController.openDocument()` gains three more category branches (`word`, `excel`, `powerpoint`), the same seam `FEATURE-OPENREADER-P2` used for `pdf`. `DocumentCategory` already has the right enum values (`word`/`excel`/`powerpoint`) — confirmed by reading `document_category.dart`, no model change needed.

**Library research: done 2026-09-18; Word and Excel implemented the same day.** `docx_file_viewer` (native rendering + built-in search) for Word, `excel_plus` (fast, well-adopted parser) plus a first-party grid widget for Excel — both free (MIT/Apache-2.0), no licensing gate. [ADR-OPENREADER-office-libraries](../project-context/features/FEATURE-OPENREADER-P3/adr/ADR-OPENREADER-office-libraries.md) — **Accepted** ("Yes" — approving and starting implementation). See [TASK-011](../project-context/features/FEATURE-OPENREADER-P3/tasks/TASK-011.md) for the as-built design and two real gaps found during implementation: Word's reading position can be saved but not restored (the library exposes no scroll-control API at all), and `DocxView` could not be exercised via `flutter test` in this environment (hangs; root cause not identified, isolated to the widget layer specifically).

**PowerPoint is the one real open problem.** No free library found renders PPTX content natively with adequate fidelity — even the strongest actively-maintained multi-format alternative found (`universal_file_viewer`) falls back to opening PPTX in an external app rather than claim inline rendering it can't deliver. This is a verified finding, not a gap in this session's research effort — see `ARCHITECTURE.md` Alternatives for the specific packages checked and why each was insufficient. Three ways forward are laid out in `SRS.md` Unresolved Question 1, none decided here, since it's a product tradeoff (fidelity vs. effort vs. timeline), not an engineering one.

Two other items are explicitly deferred, not silently dropped: legacy binary format support (`.doc`/`.xls`/`.ppt`, BRD §30 says "where feasible," not required) and password-protected Office files (no candidate library's documentation confirms support, unlike PDF's `pdfrx`) — both tracked as `SRS.md` Unresolved Questions 2 and 3.

## Validation and handoff

**Word and Excel implemented 2026-09-18** (see [TASK-011](../project-context/features/FEATURE-OPENREADER-P3/tasks/TASK-011.md) for the full implementation delta). `flutter analyze`: 0 errors/warnings (158 pre-existing infos, unchanged baseline). `flutter test`: 91/91 passing (65 pre-existing + 26 new). Unlike PDF, both libraries are pure Dart, so real `.docx`/`.xlsx` files were built and round-tripped through each reader's own controller in these tests — genuinely stronger verification than fixture-only tests, though `DocxView`'s actual on-screen rendering and both readers' behavior against a real device remain unverified (see TASK-011's gaps).

Remaining open items:
1. Decide PPTX's path forward (`SRS.md` Unresolved Question 1) — a product decision, not yet made; blocks a PPTX-specific ADR and its implementation, not Word/Excel (already done).
2. Decide legacy-format and password-flow scope, or explicitly accept the current gaps (`SRS.md` Unresolved Questions 2–3; TASK-011's own gaps for Word/Excel specifically).
3. Word's reading-position restore is unimplementable with `docx_file_viewer` 1.0.4 as-is — revisit if a future release adds scroll-control, or accept save-only as this phase's answer for Word.

## Process note

Routed through the same scoping approach as `FEATURE-OPENREADER-P2` and TASK-007's architecture pass — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
