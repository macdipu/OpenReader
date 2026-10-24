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

### One widget for any file

```dart
import 'package:open_reader_kit/open_reader_kit.dart';

DocumentViewer.file(
  path,
  initialPosition: savedPosition,           // reopen where the reader left off
  onPositionChanged: (position) => save(position),
)
```

`DocumentViewer` picks the reader by file type. Positions are plain JSON-safe maps (`ReadingPosition`, keys in `PositionKeys`), so store them anywhere.

### Per-format readers
For your own app bar, search UI or saving, use the controller and view for each format. Every controller is a plain `ChangeNotifier` (no state-management package). Each takes an `initialPosition`, reports through `onPositionChanged`, and exposes a typed `DocumentLoadError`.

| Import | Controller | View |
|---|---|---|
| `package:open_reader_kit/pdf.dart` | `PdfDocumentController` (pages, layout, zoom, search, text-layer check) | `PdfDocumentView` |
| `package:open_reader_kit/docx.dart` | `WordDocumentController` (parsed off the UI isolate; continuous or print layout; search, position restore) | `WordDocumentView` (lazy continuous view, or print layout with measured pages, per-page headers/footers and live page numbers; styles, lists, tables with merges, images, links, footnotes/endnotes) |
| `package:open_reader_kit/sheets.dart` | `SpreadsheetController` (.xlsx and CSV: sheets, hidden sheets, search, zoom, links) | `SheetGrid` (lazy 2D grid: file's column widths/row heights, hidden rows/columns, frozen panes, merged cells, text formatting; row/column selection with Count/Sum/Avg) |
| `package:open_reader_kit/slides.dart` | `SlideDeckController` (.pptx: slides, search) | `SlideDeckView`, `SlideNavigationBar` |
| `package:open_reader_kit/text.dart` | `TextDocumentController` (encoding, binary check, search) | `TextDocumentView` |

Lower-level pieces:
- `open_reader_kit.dart`: `DocumentFormat` (file type from extension, path or MIME type), `ZipSafetyGuard`, `decodeTextBytes`.
- `word.dart`: the Word engine on its own (`DocxReader`, the `WordDocument` model).
- `testing.dart`: `buildPptx` and `buildXlsx` for tests.

## Layout

| Path | What |
|---|---|
| `lib/src/viewer/` | `DocumentViewer` |
| `lib/src/pdf_reader/`, `word/`, `sheets/`, `slides/`, `text/` | The readers: controllers and views |
| `lib/src/common/` | Format detection, ZIP safety, text decoding, reader conventions |
| `lib/src/engines/pdf/` | PDF: `viewer/` widgets, `core/` document API, `pdfium/` FFI bindings, `pdfium_flutter/` loader |
| `lib/src/engines/word/` | Word (own engine): `.docx` reader, document model, styles and numbering |
| `lib/src/engines/ooxml/` | Office package layer (own): ZIP parts and relationships, shared by the .xlsx and .pptx readers |
| `lib/src/engines/sheets/` | Spreadsheets (own engine): `.xlsx` and CSV readers, workbook model, number formats |
| `hook/` | Native-asset hooks: download PDFium (Android, Windows, Linux) and drop it on iOS |
| `darwin/` | iOS/macOS plugin (`OpenReaderKitPlugin`): links the PDFium xcframework (CocoaPods + SwiftPM) |
| `assets/pdfium/` | PDFium WASM for the web |

The engines started from open-source packages; `NOTICE.md` lists where each came from, with its license. They are now maintained here.

## Roadmap
**Publishing:**
- `publish_to: none` until the first pub.dev release.
- Before then, review the engines' analyzer warnings (30 redundant `!`, 5 `return` without `await` in a `try`).
- Decide the localisation story; `DocumentViewer`'s fallback messages are English.

## License
- The kit's own code belongs to the OpenReader project.
- The engine code keeps its original MIT / Apache-2.0 terms; see `NOTICE.md` and `licenses/`.
