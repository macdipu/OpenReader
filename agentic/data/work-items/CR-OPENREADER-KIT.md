# CR-OPENREADER-KIT: extract an `open_reader_kit` package (all document engines as editable source)

## Request (user, 2026-10-23)
- "why not build this app own package for app which can read all type of doc in future i will release package, and use this app as example to that package"
- "yes, open_reader_kit in packages/, go ahead pull all raw code from respetcted code so that i can fix add new feature as i want, first do that pland, double check and finaly is start"

## Decision (user, in-session 2026-10-23)
- **Package:** `open_reader_kit`, in this repo under `packages/`.
- **Engines:** every document engine the app uses becomes editable source inside the kit ("pull all raw code"), so the user can fix bugs and add features in them directly.
- **The app** becomes the kit's full example: it depends on the kit by path.
- **Release:** the user plans to publish the kit to pub.dev later. That step is not part of this CR.

## Plan
See `features/CR-OPENREADER-KIT/TECH-SPEC.md`.

## Run
`RUN-D7532679987249979346FE2D4A723869` (technical approval recorded, at IMPLEMENTATION). Context scoped to the frozen TECH-SPEC only.

## Phase A: done (2026-10-23)
- **What was copied:** the 8 engines, verbatim, into `packages/open_reader_kit/third_party/` (see `VENDORED.md`).
- **Wiring:** the kit depends on them by path. The app depends on the kit and on the engines by path, and its overrides send the transitive engines to the copies too.
- **Checks:**
  - Analyze is clean for both the app and the kit.
  - All 235 tests pass.
  - The APK bundles `libpdfium.so`.
  - PDF, DOCX, XLSX and PPTX all open on the emulator.
- **Not committed.**

## Amendment 1: done (2026-10-23)
- **User's request:** "why these tharparty why not bring open source code maintain" and "why not chnage there naming? as they are now and will maintain by me?"
- **Spec:** `features/CR-OPENREADER-KIT/TECH-SPEC-AMENDMENT-1.md`.
- **What changed:**
  - The engines are now open_reader_kit's own code under `lib/src/engines/{pdf,docx,excel}`, and `third_party/` is gone.
  - Entry points: `open_reader_kit/pdf.dart`, `docx.dart`, `docx_core.dart` and `excel.dart`.
  - The kit is now the PDFium FFI plugin itself: `hook/`, `darwin/`, `OpenReaderKitPlugin`.
  - `NOTICE.md` and `licenses/` keep the original copyrights.
  - The app depends on `open_reader_kit` only.
- **Checks:**
  - All 235 tests pass.
  - Analyze is clean for the app. The kit has 0 errors and 35 warnings that came with the upstream code.
  - The APK bundles PDFium for 3 ABIs.
  - The macOS build bundles `PDFium.framework`.
  - PDF, DOCX and XLSX open on the emulator.
- **Example app:** listed in the kit README with its Play Store link: https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader
- **Not committed.**
- **Next:** Phase B, moving OpenReader's own readers into the kit.
