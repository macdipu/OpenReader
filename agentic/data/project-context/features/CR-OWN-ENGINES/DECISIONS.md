# CR-OWN-ENGINES: decisions on the TECH-SPEC's open questions

TECH-SPEC.md stays frozen as the run's context. The user's answers are recorded here (in-session, 2026-10-24).

- **Plan:** approved: "Approve" (E1 → E2 → E3 → E4 → E5).
- **Q1, web:** **dropped for 0.1.0.** The kit targets Android, iOS, macOS, Windows and Linux. E3 doesn't build a PDFium wasm. The web assets (`assets/pdfium/`) go away with the old PDF engine. Web can come back in a later release.
- **Q2, Word fidelity:** the user chose all three options:
  1. Today's level: continuous view, styles, lists, tables, images, links, page breaks, search, headers and footers.
  2. **Footnotes and endnotes,** shown at the end of the document.
  3. **A paged print layout** as an option next to the continuous view.

  E2 grows to cover these.
- **Q3, kit license:** **MIT** (user, in-session 2026-10-24: "MIT, push it"). The copyright holder in `packages/open_reader_kit/LICENSE` is "chowdhuryelab", the GitHub org the user chose for the kit's repo. The user was told they can change it to a legal name.

## Amendment (user, in-session 2026-10-24): idea-level reference to the old engines
- **User's words:** "do look old code took the idea and write them in better way scalabe way"
- **What replaces the TECH-SPEC's clean-room rule from now on:**
  - The old engines (in the working tree, or in git history for removed ones) may be read for **ideas**: features, edge cases and design approaches.
  - New code is still written fresh, with our own structure, names and design. Old code is never copied, translated or paraphrased.
- **What the user was told:**
  - Copyright covers how code is expressed, not the ideas, so the result stays the kit's own code.
  - Clean-room is the stronger defence if the code's origin is ever questioned. Reading the old source first gives that up.
- **Applies to:** E1 follow-up work (layout features, a shared OOXML package layer), E2 and E3.
