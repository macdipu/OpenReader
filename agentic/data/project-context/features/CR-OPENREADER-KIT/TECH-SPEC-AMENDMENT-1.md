# TECH-SPEC amendment 1: engines become open_reader_kit's own code

Approved by the user in-session, 2026-10-23:
- "why these tharparty why not bring open source code maintain"
- "why not chnage there naming? as they are now and will maintain by me?"

This amendment replaces Phase A's `third_party/` layout. The base TECH-SPEC stays frozen as the run's context.

## Layout
The engines are no longer separate packages. Their `lib/` code moves into the kit under new names:

| Was | Now |
|---|---|
| pdfrx | `lib/src/engines/pdf/viewer/` |
| pdfrx_engine | `lib/src/engines/pdf/core/` |
| pdfium_dart | `lib/src/engines/pdf/pdfium/` |
| pdfium_flutter | `lib/src/engines/pdf/pdfium_flutter/` |
| docx_file_viewer | `lib/src/engines/docx/viewer/` |
| docx_creator | `lib/src/engines/docx/core/` |
| excel_plus | `lib/src/engines/excel/core/` |
| csv_plus | `lib/src/engines/excel/csv/` |

Public entry points:
- `package:open_reader_kit/pdf.dart`
- `package:open_reader_kit/docx.dart` (viewer)
- `package:open_reader_kit/docx_core.dart` (parser/builder)
- `package:open_reader_kit/excel.dart`

Every `package:<engine>/…` import is rewritten to `package:open_reader_kit/src/engines/…`.

## Native PDFium
The kit becomes the FFI plugin:
- **`hook/build.dart`** comes from pdfium_dart. It downloads the PDFium binary, emitted as code asset `package:open_reader_kit/libpdfium`.
- **`hook/link.dart`** merges the two link hooks. The PDFium asset is omitted on iOS, where the xcframework provides PDFium. The metadata hand-off between the two packages is no longer needed inside one package.
- **iOS/macOS:**
  - `darwin/open_reader_kit.podspec`
  - `darwin/open_reader_kit/Package.swift` for SwiftPM; it keeps the same PDFium xcframework URL and checksum.
  - Plugin class `OpenReaderKitPlugin`.
- **Web:** pdfrx's WASM assets move to `assets/pdfium/`. The default module path becomes `assets/packages/open_reader_kit/assets/pdfium/`.
- **Dropped:** pdfrx's `bin/` tools, which worked around duplicate Darwin PDFium modules between pdfrx and pdfium_flutter. One package removes that problem.

## Licenses
`NOTICE.md` lists each original package, version, copyright and license. The full license texts are kept in `licenses/`. MIT and Apache-2.0 both require this; the Apache license also requires stating that the files were modified.

## Removed
- `third_party/`
- the app's direct and override dependencies on the engines; the app now depends on `open_reader_kit` only.

Upstream examples and tests are not carried over. The app's 235 tests cover the engines in use.

## Verify
- `flutter analyze` is clean for the app and the kit.
- All 235 tests pass.
- The APK contains `libpdfium.so`.
- The macOS debug build works, which proves the darwin plugin and the SwiftPM package.
- On the emulator, PDF, DOCX, XLSX and PPTX open.
