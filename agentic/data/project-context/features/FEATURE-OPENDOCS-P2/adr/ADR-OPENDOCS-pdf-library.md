# ADR-OPENDOCS-pdf-library: PDF rendering library for the Phase 2 reader

## Status
**Accepted.** The user approved this ADR's Decision explicitly (2026-09-18): "Approve it, start implementation." `pdfrx: 2.4.8` is the library for Phase 2.

## Context
BRD §30 Phase 2 (PDF Reader) needs, at minimum, offline rendering, zoom, multiple view modes, page thumbnails, jump-to-page, a password-protected-PDF flow, and full-text search with highlighting (BRD §9.10, §30's own Phase 2 deliverable list). No PDF library exists in this project yet (`pubspec.yaml` has none as of `FEATURE-OPENDOCS-P1`/TASK-007).

Four candidates were evaluated, each verified directly against its current pub.dev listing, README, CHANGELOG, and LICENSE file rather than from memory (three of the four packages had releases after this assistant's training cutoff, so recalled details could have been stale):

- **`pdfx`** (MIT): rendering-only. Its `password` parameter is documented as working only on Web — not Android or iOS, this app's actual targets. No search or thumbnail widgets.
- **`flutter_pdfview`** (MIT): wraps a native `PlatformView`. `password` genuinely works on both Android and iOS. Search is listed in the maintainer's own "Future plans" — not implemented. Being a platform view, custom overlays like search-highlight boxes are difficult to build well even once search exists.
- **`syncfusion_flutter_pdfviewer`**: covers nearly the entire BRD §9.10 feature list out of the box (search+highlight, bookmarks/TOC, thumbnails, password, multiple view modes). Licensed under Syncfusion's Essential Studio program — free only under their Community License, which requires the licensee's organization to have gross revenue under $1,000,000/year **and** fewer than 5 developers; otherwise a paid commercial license is required. Verified by reading the package's own `LICENSE` file directly, not a summary.
- **`pdfrx`**: MIT-licensed, and its latest release (`2.6.1`) advertises built-in text selection, search, and zoom. Initially ruled out during scoping because `2.6.1` requires Flutter ≥3.47.0, newer than this project's `.fvmrc`-pinned 3.44.4.

The product owner then stated explicitly: "I don't want to pay anything." That rules out Syncfusion's paid tier outright, and given no confirmation the project qualifies for (or wants to rely on the durability of) the Community License's revenue/team-size gate, it rules out Syncfusion entirely for this decision — not because the license is inherently unacceptable in general, but because "don't want to pay anything" is the simplest reading of that instruction and the gated free tier still carries eligibility risk this ADR should not paper over.

Re-examining `pdfrx`'s own version history (its CHANGELOG and pub.dev's per-version `environment` metadata) found that the Flutter ≥3.47.0 requirement was only introduced starting at version `2.5.0`; versions `2.3.0` through `2.4.8` require Flutter ≥3.41.0, which this project's pinned 3.44.4 satisfies. The CHANGELOG confirms `2.4.8`'s own changes are bug fixes *to* text selection (not the feature's introduction), and password support (`PasswordProvider`/`PdfPasswordException`) was introduced considerably earlier in the version history — both features are already present and stable at `2.4.8`.

This was verified for real, not just reasoned about: `pdfrx: 2.4.8` was added to this project's `pubspec.yaml` and `flutter pub get` was run. It resolved cleanly — 11 new/changed transitive packages, no dependency conflicts against the existing ~60 dependencies. `flutter analyze` afterward still reported 0 errors/0 warnings (158 pre-existing infos, the same baseline TASK-008 and TASK-007 recorded). The change was reverted before this ADR's approval, since approval should precede the change landing, not follow it.

## Decision
**Use `pdfrx`, pinned to version `2.4.8` (not the latest `2.6.1`), for the PDF reader.** This is the only evaluated option that is simultaneously: free (MIT, no revenue/team-size gate), requires no bump to this project's pinned Flutter SDK, and already provides real (non-web-only, non-roadmap) text search and password-protected-PDF support without custom engineering for either.

Thumbnails and jump-to-page are **not** library-provided widgets in any of the evaluated options and will be built as first-party OpenDocs UI on top of `pdfrx`'s page-image/page-controller primitives — this is true regardless of which library had been chosen, so it is not a cost specific to this decision.

## Alternatives
1. **`pdfrx` (chosen), pinned to `2.4.8`.** Free, no SDK bump, real search + password. Cost: misses `2.5.0+`'s bug fixes (WASM/text-search edge cases, a Windows race condition, progressive-loading improvements per the CHANGELOG) until this project's own Flutter SDK is eventually bumped past 3.47.0.
2. **`pdfrx`, latest (`2.6.1`), with a Flutter SDK bump to ≥3.47.0.** Gets the same features plus recent bug fixes, but requires bumping `.fvmrc` and re-verifying all ~60 other dependencies against the new SDK floor — a larger, separate decision this ADR does not make. Worth revisiting later; not chosen now because it's more change than this phase needs to start.
3. **`pdfx` + hand-built search and password UI.** Free, no SDK concern, but ODF-P2-05 (password) has no working path on Android/iOS through this package at all — would need a lower-level PDFium binding or a fork, which is materially more engineering and risk than adopting a slightly older `pdfrx` release.
4. **`flutter_pdfview` + hand-built search.** Free, password works natively, but search would be built entirely from scratch on top of a `PlatformView`, which is a harder surface to overlay custom UI on than `pdfrx`'s Flutter-native rendering.
5. **`syncfusion_flutter_pdfviewer`.** Most complete out of the box, but ruled out per the product owner's explicit no-paid-dependency instruction; the Community License's eligibility gate (revenue and team size) is also not something this ADR can verify or assume.

## Consequences
- Phase 2 implementation can start once this ADR is approved, without a separate Flutter-SDK-bump decision blocking it.
- The dependency pin (`pdfrx: 2.4.8`, not a caret/range constraint like this project's other dependencies) is deliberate and should not be "helpfully" widened by a future contributor or dependency-update tool without first re-confirming the Flutter SDK floor — `pubspec.yaml` should carry a comment saying so.
- Bumping the Flutter SDK later (to adopt `pdfrx` 2.5.0+ or for unrelated reasons) is explicitly left open, not foreclosed — Alternative 2 above documents the path.
- No new Android/iOS permission is introduced; `pdfrx` renders via PDFium locally, consistent with BRD §15's offline mandate.

## Risks
1. **Version-pin drift.** If a future change bumps `pdfrx` without also checking the Flutter SDK floor, the build could silently start requiring a newer Flutter than `.fvmrc` declares, surfacing as a confusing `flutter pub get` failure rather than a clear decision point. Mitigate with the `pubspec.yaml` comment noted above.
2. **`pdfrx` is a smaller, single-maintainer-style project** relative to Syncfusion's commercial backing — verified active (published 2026-09-04) at the time of this decision, but its bus-factor and long-term support posture is weaker than a commercial vendor's. Accepted as a reasonable tradeoff for a free, non-web-restricted, SDK-compatible option; not a reason to reverse this decision without a concrete problem showing up.
3. **Large/complex PDF corpus (BRD §12.6) is unverified against `pdfrx` specifically** — this ADR does not claim performance parity with any alternative; that needs its own test-corpus pass during implementation (`ARCHITECTURE.md` Risk 2), not assumed here.

## References
- `ARCHITECTURE.md` (Alternatives Considered, ADR Recommendation)
- `SRS.md` (Unresolved Specification Question 1)
- `agentic/data/project-context/features/FEATURE-OPENDOCS-P1/adr/ADR-OPENDOCS-storage-access.md` (process precedent this ADR follows)
- pub.dev and GitHub for `pdfx`, `flutter_pdfview`, `syncfusion_flutter_pdfviewer`, `pdfrx` (versions, licenses, and per-version SDK constraints verified 2026-09-18)
