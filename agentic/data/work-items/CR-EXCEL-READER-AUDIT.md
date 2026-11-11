# CR-EXCEL-READER-AUDIT: audit-first requirements for the read-only Excel reader

## Run
`RUN-6780549E98B74690B709F92E03DE3083` (change_request, planning NO_REPLAN), registered 2026-11-11 while `RUN-60D2C2882A324C15AAD0FBB0A9DC42DF` (CR-OWN-ENGINES) waits at REVIEW. The user chose to finish CR-OWN-ENGINES' IMPLEMENTATION result first, then start this CR.

## Request (user, 2026-11-11)
A pasted requirements document, "Excel Reader: Audit-First Requirements". In short:
- **Audit before implementation.** Do not rebuild, redesign or replace the existing reader. Trace the whole flow (import, parse, workbook model, grid, formatting, selection, search/filter/sort, export/print), check desktop, tablet and mobile, run the app and tests, and record each requirement as Implemented / Partial / Missing / Broken / Unsupported with a P0/P1/P2 priority.
- **Deliver an audit report first**: feature inventory, source files per feature, device behaviour, bug reproductions, performance and accessibility notes, risks, recommended order.
- **Implement only approved gaps**, using the current architecture. No second selection engine, no new spreadsheet library without a documented limitation and approval.
- **Scope is read-only.** No editing, no recalculation engine, no AI, accounts or cloud sync.
- Sections 4 to 15 of the request list the capabilities to verify: file types (.xlsx .xls .xlsm .csv .tsv), grid rendering and formatting, selection on desktop and touch, selection statistics, copy, search and go-to, sort and filter (non-destructive), responsive layouts, zoom/freeze panes, export and print, performance, accessibility, security.
- Sections 16 to 19: testing requirements, implementation rules, the execution workflow and the definition of done.

The full text is in the session that created this work item; it is not copied here. The numbered sections above are the traceability anchors.

## Known starting facts (from the repo, before the audit)
- Spreadsheet engine is the package `universal_document_viewer` (own repo `github.com/macdipu/universal_document_viewer`, local checkout `../universal_document_viewer`), used by the app by git ref `main`. Changes to the grid or parser are made there, then the app's pin is bumped.
- Legacy `.xls` is a known backlog item, `CR-LEGACY-OFFICE`, "coming soon": the audit should record it as Unsupported rather than plan it again.
- Earlier work on this reader: `CR-OPENREADER-SHEETS` (row/column selection, formula results, hidden sheets; hidden sheets and row selection were not re-checked on a device) and CR-OWN-ENGINES E1c/E1d (borders, conditional formatting, notes, formulas, go to cell, freeze header).
- Verified 2026-11-11: app 264 tests and package 250 tests pass; analyze has no errors or warnings.

## Plan
1. INTAKE (this document).
2. CONTEXT: reconnaissance and behaviour audit, producing `agentic/data/project-context/features/CR-EXCEL-READER-AUDIT/AUDIT-REPORT.md`.
3. Stop for the user's approval of the prioritized gap list. No implementation before that.

## Status
INTAKE. Audit in progress.
