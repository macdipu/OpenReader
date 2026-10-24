# open_reader_kit

Open and read documents in Flutter: PDF, Word (.docx), Excel (.xlsx), CSV, PowerPoint (.pptx) and plain text. The document engines are part of the package (PDF runs on PDFium; Word, spreadsheets and slides are read by Dart code written for this package), so there is no other document plugin to add.

Use one widget, `DocumentViewer.file(path)`, that picks the right reader for the file type, or use the controller and view for each format when you want your own app bar, search UI or saving.

## Features

**PDF** (`pdf.dart`)
- Continuous (vertical) or horizontal page layout.
- Pinch, double-tap and mouse-wheel zoom; zoom in/out steps and fit-width from the controller.
- Pages are built only near the viewport, with a low-resolution image per page sharpened by tiles when zoomed in.
- Password-protected PDFs, through a password callback.
- Search across all pages with highlights, and a check for scanned PDFs without a text layer.
- Links: web links open outside the app (`http`, `https`, `mailto` only); links to pages jump.

**Word** (`docx.dart`)
- Continuous layout reflowed to the screen, or print layout with measured pages, per-page headers and footers and live page numbers.
- Paragraph and character styles, lists, tables with merged cells, images, links and bookmarks, footnotes and endnotes.
- Parsed in a background isolate; search with highlights; scroll position restore.

**Spreadsheets** (`sheets.dart`)
- Excel `.xlsx` and CSV.
- A lazy 2D grid: only on-screen cells are built.
- The file's column widths and row heights, hidden rows, columns and sheets, frozen panes, merged cells, text formatting and number formats.
- Several sheets, search, zoom, and cell links (web links and links to other cells).
- Select a row or column to see its Count, Sum and Average.

**PowerPoint** (`slides.dart`)
- `.pptx` slides shown as titles, paragraphs, tables and pictures, one slide at a time, with a navigation bar and search.

**Text** (`text.dart`)
- `.txt` and Markdown (`.md`, `.markdown`) shown as plain text, UTF-8 with a Latin-1 fallback.
- Rejects binary files; search with highlights.

**All formats**
- File type detection from the extension, path or MIME type (`DocumentFormat`).
- Office files are checked before parsing (`ZipSafetyGuard`): damaged ZIPs, path traversal and oversized ("zip bomb") contents are refused.
- Reading positions as plain JSON-safe maps, and typed load errors.

Legacy binary `.doc`, `.xls` and `.ppt` files are not supported.

## Platforms

Android, iOS, macOS, Windows and Linux. Web is not supported yet.

## Installation

open_reader_kit is not on pub.dev yet. Until it is, depend on it by path or git:

```yaml
dependencies:
  open_reader_kit:
    git:
      url: <repo-url>
      path: packages/open_reader_kit
```

or, with a local checkout:

```yaml
dependencies:
  open_reader_kit:
    path: ../open_reader_kit
```

It needs Dart 3.11.4 or later and Flutter 3.41 or later.

### PDFium

The PDF engine needs the PDFium native library. You don't add it yourself: the package's build hook (`hook/build.dart`) downloads a prebuilt PDFium for the target platform from [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries) at build time. The release is pinned and every archive is checked against a pinned SHA-256 before it is used. The first build for each platform therefore needs network access.

## Quick start

```dart
import 'package:open_reader_kit/open_reader_kit.dart';

DocumentViewer.file(
  path,
  initialPosition: savedPosition, // reopen where the reader left off
  onPositionChanged: (position) => save(path, position),
  errorBuilder: (context, error) => Center(child: Text('Cannot open: ${error.name}')),
)
```

`DocumentViewer` picks the reader by file type: PDF, Word, Excel (with sheet tabs), CSV, PowerPoint (with slide navigation) or text. It shows a short English message when a file can't be opened, unless you pass `errorBuilder`.

See [`example/`](example/) for a runnable app.

## Per-format readers

Every controller is a plain `ChangeNotifier` (no state-management package). Each takes an `initialPosition`, reports changes through `onPositionChanged`, and has `search`, `clearSearch`, `nextMatch` and `previousMatch`. Dispose controllers you create.

| Import | Controller | View |
|---|---|---|
| `package:open_reader_kit/pdf.dart` | `PdfDocumentController` | `PdfDocumentView` |
| `package:open_reader_kit/docx.dart` | `WordDocumentController` | `WordDocumentView` |
| `package:open_reader_kit/sheets.dart` | `SpreadsheetController` | `SheetGrid` |
| `package:open_reader_kit/slides.dart` | `SlideDeckController` | `SlideDeckView`, `SlideNavigationBar` |
| `package:open_reader_kit/text.dart` | `TextDocumentController` | `TextDocumentView` |

### PDF

The view opens the file itself; the controller drives it.

```dart
import 'package:open_reader_kit/pdf.dart';

final controller = PdfDocumentController(onPositionChanged: save);

PdfDocumentView(
  path: path,
  controller: controller,
  passwordProvider: () => askForPassword(), // Future<String?>; null gives up
);

controller.zoomIn();
controller.zoomOut();
controller.fitWidth();
controller.toggleViewMode(); // continuous <-> horizontal
controller.jumpToPage(10);
controller.search('invoice'); // results in controller.searchController
```

### Word

```dart
import 'package:open_reader_kit/docx.dart';

final controller = WordDocumentController(initialPosition: saved, onPositionChanged: save);
await controller.load(await File(path).readAsBytes());

if (controller.error == null) {
  WordDocumentView(controller: controller);
}

controller.toggleViewMode(); // continuous <-> print layout (WordViewMode)
controller.search('agreement'); // matches in controller.searchController
controller.nextMatch();
```

`package:open_reader_kit/word.dart` has the Word engine on its own: `DocxReader.read(bytes)` returns a `WordDocument` model.

### Spreadsheets

```dart
import 'package:open_reader_kit/sheets.dart';

final controller = SpreadsheetController(onPositionChanged: save);
await controller.loadXlsx(bytes); // or loadCsv(bytes)

SheetGrid(controller: controller);

controller.switchSheet(1); // sheet names in controller.sheetNames
controller.zoomIn();
```

### PowerPoint

```dart
import 'package:open_reader_kit/slides.dart';

final controller = SlideDeckController(onPositionChanged: save);
await controller.load(bytes);

Column(children: [
  Expanded(child: SlideDeckView(controller: controller)),
  SlideNavigationBar(controller: controller),
]);
```

### Text

```dart
import 'package:open_reader_kit/text.dart';

final controller = TextDocumentController(onPositionChanged: save);
controller.load(bytes); // synchronous

TextDocumentView(controller: controller, fontSize: 14, wrap: true);
```

## Reading positions

A position is a `ReadingPosition`, a plain `Map<String, Object?>` of JSON-safe values. Store it as-is (for example with `jsonEncode`) and pass it back as `initialPosition` to reopen at the same place. The keys are in `PositionKeys`:

| Reader | Keys |
|---|---|
| PDF | `pageNumber`, `pageCount`, `viewMode` |
| Word | `scrollOffset`, `viewMode` |
| Spreadsheets | `sheetIndex`, `verticalOffset`, `horizontalOffset`, `row`, `column` |
| PowerPoint | `slideIndex`, `slideCount` |
| Text | `scrollOffset` |

Positions are reported as the reader moves; debouncing the saves is up to you.

## Errors

The Word, spreadsheet, PowerPoint and text controllers expose `error` as a `DocumentLoadError`:
- `tooLarge`: the file, or a ZIP's declared contents, is bigger than the reader will load.
- `corrupted`: damaged or truncated, or an encrypted Office file.
- `passwordRequired`: an encrypted PDF without (or with a wrong) password.
- `unsupported`: not a format the kit reads.

The wording is yours. `PdfDocumentController.error` holds the PDF engine's exception (`PdfOpenException` or `PdfEngineException`), and `DocumentViewer` maps every failure to a `DocumentLoadError` for its `errorBuilder`.

## Thumbnails

A `DocumentThumbnails` API for first-page previews is being added.

## Other libraries

- `open_reader_kit.dart`: `DocumentViewer`, `DocumentFormat`, `ReadingPosition`, `PositionKeys`, `DocumentLoadError`, `ZipSafetyGuard`, `decodeTextBytes`.
- `word.dart`: the Word engine (`DocxReader`, the `WordDocument` model).
- `testing.dart`: `buildDocx`, `buildXlsx` and `buildPptx` build small documents in memory for tests.

## Showcase: OpenReader

**OpenReader** is a document reader app built on open_reader_kit and shows everything it does:
- Google Play: https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader
- Source: the app in this repository (`../../`), which depends on the kit by path.

## Licence

The licence for open_reader_kit is to be decided (TBD) before the first release.

Third-party code and the PDFium binary keep their own licences; see [`NOTICE.md`](NOTICE.md) and `licenses/`.
