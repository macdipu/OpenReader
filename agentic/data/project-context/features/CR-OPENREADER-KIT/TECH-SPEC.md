# TECH-SPEC: CR-OPENREADER-KIT

Status: APPROVED by the user in-session, 2026-10-23: "go ahead … first do that pland, double check and finaly is start".

## Goal
`packages/open_reader_kit`: one Flutter package that opens PDF, Word (.docx), Excel (.xlsx), CSV, PowerPoint (.pptx) and text.
- Every document engine it uses is **source code in the repo** that the user can edit.
- OpenReader (this app) becomes its full example app.

## What gets vendored (engine source, copied verbatim at the versions locked in `pubspec.lock`)

| Engine package | Version | License | Dart lines | Used for |
|---|---|---|---|---|
| `pdfrx` | 2.4.8 | MIT | 13.5k | PDF viewer widgets |
| `pdfrx_engine` | 0.4.7 | MIT | 7.8k | PDF document API |
| `pdfium_flutter` | 0.2.3 | MIT | <0.1k + native glue | PDFium loading for Flutter |
| `pdfium_dart` | 0.2.5 | MIT | 14.3k (FFI bindings) | PDFium bindings + build hook |
| `docx_file_viewer` | 1.0.4 | Apache-2.0 | 5.3k | Word → widgets |
| `docx_creator` | 1.3.3 | MIT | 42.9k | .docx parser used by the viewer |
| `excel_plus` | 2.22.0 | MIT | 30.6k | .xlsx/.csv parser |
| `csv_plus` | 1.9.0 | MIT | 5.1k | CSV parser used by excel_plus |

Layout:
- Each engine goes to `packages/open_reader_kit/third_party/<name>/`, unchanged. Its `LICENSE` is kept.
- `packages/open_reader_kit/third_party/VENDORED.md` records each engine's origin, version, license and the date it was copied.
- The user's later edits are made on top of that copy. VENDORED.md has a "Local changes" section for them.

### Not vendored (deliberately)
- **PDFium itself:** Google's C++ engine, millions of lines. `pdfium_dart`'s build hook keeps downloading the prebuilt binaries from `bblanchon/pdfium-binaries`. The Dart side (bindings and hook) is vendored and editable.
- **General-purpose libraries:** `archive`, `xml`, `image`, `http`, `rxdart` and others are not document engines. They stay hosted on pub.dev and can be vendored later the same way if needed.

## Wiring
- `packages/open_reader_kit/pubspec.yaml` depends on the vendored engines by `path:`.
- The app depends on `open_reader_kit` by `path:`. The app's direct `pdfrx`, `docx_file_viewer` and `excel_plus` entries also switch to the vendored paths.
- The app's `dependency_overrides` point the transitive engines (`pdfrx_engine`, `pdfium_flutter`, `pdfium_dart`, `docx_creator`, `csv_plus`) at their vendored copies. That way the **whole** dependency tree uses the in-repo source, with no hosted duplicate.
- **Analysis:** the root `analysis_options.yaml` excludes `packages/**`, so the vendored engines' own lint settings don't flood the app's analysis. Each package is analysed in its own folder.

## Phases

### A. Vendor the engines (this session)
1. Scaffold `packages/open_reader_kit`: pubspec, README, LICENSE note, `lib/open_reader_kit.dart`, `third_party/VENDORED.md`.
2. Copy the 8 engines verbatim, without `build/`, `.dart_tool/` or `pubspec.lock`.
3. Wire the path deps and overrides as above.
4. Verify:
   - `flutter pub get` resolves every engine to `packages/…`; check this in `pubspec.lock` (`source: path`).
   - `flutter analyze lib test` shows no errors or warnings.
   - The full test suite passes (235 tests).
   - The debug APK builds; PDFium is still fetched by the hook.
   - Smoke test on the emulator: open a PDF, a .docx, an .xlsx and a .pptx.

### B. Move OpenReader's own reader code into the kit (next sessions)
1. Pure code with no app ties:
   - `PptxParser`
   - `ZipSafetyGuard`
   - text decoding
   - `CellText`/`CellNumber`
   - `DocumentCategory` detection
2. Excel/CSV grid: `CellGrid` with selection and zoom, its controller moved off GetX to `ChangeNotifier`.
3. PowerPoint and Text readers.
4. Word and PDF readers.
5. `DocumentViewer(source)` picks the right reader by type.

Rules for the kit's public API:
- No GetX, no sqflite.
- Reading position goes through callbacks (`initialPosition` / `onPositionChanged`).
- Errors are typed (`tooLarge`, `corrupted`, `unsupported`).

The app keeps its GetX controllers and database and adapts to the kit. Tests move along with the code they cover.

### C. Publishing prep (later; needs the user's release decision)
- **Path dependencies:** pub.dev rejects them, and `dependency_overrides` don't apply to a published package. Before publishing, each vendored engine must either be folded into `open_reader_kit/lib/src/…` or renamed (e.g. `open_reader_kit_pdfium`) and published.
- **Licenses:** Apache-2.0 (`docx_file_viewer`) requires keeping its license and stating changes. MIT requires keeping the copyright notice.
- **Release checks:** `dart pub publish --dry-run`, `example/`, CHANGELOG, and versioning separate from the app.

## Risks and checks
- **Native build:** `pdfium_flutter` has android/darwin plugin folders and a hook. A path copy must keep them, or PDF breaks at build time. Covered by the APK build and the PDF smoke test.
- **Version drift:** the copies are frozen. Upstream fixes are no longer picked up automatically. VENDORED.md records the base version, so updates can be diffed by hand.
- **Repo size:** about 120k Dart lines are added; examples and tests are kept as-is.
