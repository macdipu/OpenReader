# Notices

open_reader_kit's document engines started as copies of the open-source packages below, taken on 2026-10-23. Since then they have been modified and are maintained as part of open_reader_kit.

The modifications so far:
- Each package was moved under `lib/src/engines/`.
- Imports were rewritten to the new paths.
- The native PDFium plugin parts (build/link hooks, iOS/macOS podspec, Swift package) were merged into this package and renamed.

The full original license texts are in `licenses/`. They still apply to the code that came from each package.

| Now in open_reader_kit | Original package | Version | License | Copyright |
|---|---|---|---|---|
| `lib/src/engines/pdf/viewer/`, `assets/pdfium/` | [pdfrx](https://pub.dev/packages/pdfrx) | 2.4.8 | MIT | Takashi Kawasaki |
| `lib/src/engines/pdf/core/` | [pdfrx_engine](https://pub.dev/packages/pdfrx_engine) | 0.4.7 | MIT | Takashi Kawasaki |
| `lib/src/engines/pdf/pdfium/`, `hook/` | [pdfium_dart](https://pub.dev/packages/pdfium_dart) | 0.2.5 | MIT | Takashi Kawasaki |
| `lib/src/engines/pdf/pdfium_flutter/`, `darwin/` | [pdfium_flutter](https://pub.dev/packages/pdfium_flutter) | 0.2.3 | MIT | Takashi Kawasaki |
| `lib/src/engines/docx/viewer/` | [docx_file_viewer](https://pub.dev/packages/docx_file_viewer) | 1.0.4 | Apache-2.0 | 2021 Mixin |
| `lib/src/engines/docx/core/` | [docx_creator](https://pub.dev/packages/docx_creator) | 1.3.3 | MIT | 2024 Ali Hassan |
| `lib/src/engines/excel/core/` | [excel_plus](https://pub.dev/packages/excel_plus) | 2.22.0 | MIT | Masum |
| `lib/src/engines/excel/csv/` | [csv_plus](https://pub.dev/packages/csv_plus) | 1.9.0 | MIT | 2025 csv_plus contributors |

PDFium itself (Google, BSD-3-Clause) is not part of this source tree. It is downloaded as a prebuilt binary:
- **Android, Windows, Linux:** from `bblanchon/pdfium-binaries`, by `hook/build.dart`.
- **iOS, macOS:** from `espresso3389/pdfium-xcframework`, by `darwin/`.
