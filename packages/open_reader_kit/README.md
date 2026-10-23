# open_reader_kit

Open and read documents in Flutter with document engines that ship as part of the package:
- PDF
- Word (.docx)
- Excel (.xlsx)
- CSV
- PowerPoint (.pptx)
- plain text

## Example app
**OpenReader** is built on open_reader_kit:
- Google Play: https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader
- Source: this repository's app (`../../`), which depends on the kit by path.

## Usage
Import the engine you need. They're separate libraries because their names overlap: the Word and spreadsheet models both have a `Border`, for example.

```dart
import 'package:open_reader_kit/pdf.dart';        // PdfViewer, PdfDocument, text search
import 'package:open_reader_kit/docx.dart';       // DocxView
import 'package:open_reader_kit/docx_core.dart';  // .docx model: parse / build
import 'package:open_reader_kit/excel.dart' as xls; // .xlsx / CSV
```

## Layout

| Path | What |
|---|---|
| `lib/src/engines/pdf/` | PDF: `viewer/` widgets, `core/` document API, `pdfium/` FFI bindings, `pdfium_flutter/` loader |
| `lib/src/engines/docx/` | Word: `viewer/` widgets, `core/` .docx parser/builder |
| `lib/src/engines/excel/` | Spreadsheets: `core/` .xlsx, `csv/` CSV |
| `hook/` | Native-asset hooks: download PDFium (Android, Windows, Linux) and drop it on iOS |
| `darwin/` | iOS/macOS plugin (`OpenReaderKitPlugin`): links the PDFium xcframework (CocoaPods + SwiftPM) |
| `assets/pdfium/` | PDFium WASM for the web |

The engines started from open-source packages; `NOTICE.md` lists where each came from, with its license. They are now maintained here.

## Roadmap
**Phase B:** OpenReader's own readers move into the kit:
- the slide viewer and `.pptx` parser
- the spreadsheet grid with row/column selection and Sum/Avg
- the text reader
- ZIP safety checks
- a `DocumentViewer` that picks the right reader by file type

The kit API won't use GetX or a database; reading position is passed in and out through callbacks.

**Publishing:**
- `publish_to: none` until the first pub.dev release.
- Before then, also review the engines' analyzer warnings: 30 redundant `!` and 5 `return` without `await` in a `try`.

## License
- The kit's own code belongs to the OpenReader project.
- The engine code keeps its original MIT / Apache-2.0 terms; see `NOTICE.md` and `licenses/`.
