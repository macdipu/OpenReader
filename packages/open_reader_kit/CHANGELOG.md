# Changelog

## 0.1.0 (unreleased)

First release.

open_reader_kit reads every format with its own engines: PDF through its own bindings to PDFium (downloaded at build time from bblanchon/pdfium-binaries, pinned release and SHA-256), and Word, Excel, CSV and PowerPoint with Dart readers written for the package from the file-format specifications.

- **Any file:** `DocumentViewer.file(path)` picks the reader by file type, restores `initialPosition`, reports `onPositionChanged` and takes an `errorBuilder`.
- **PDF:** `PdfDocumentController` and `PdfDocumentView`. Continuous or horizontal layout, pinch/double-tap/wheel zoom with tiled rendering, password-protected files, search with highlights and a text-layer check, web and page links.
- **Word (.docx):** `WordDocumentController` and `WordDocumentView`. Parsed off the UI isolate; continuous layout or print layout with measured pages, headers, footers and page numbers; styles, lists, tables with merged cells, images, links, footnotes and endnotes; search. The engine on its own is in `word.dart` (`DocxReader`, `WordDocument`).
- **Spreadsheets (.xlsx, CSV):** `SpreadsheetController` and `SheetGrid`, a lazy 2D grid. Column widths and row heights from the file, hidden rows/columns/sheets, frozen panes, merged cells, text and number formatting, links, search, zoom, row/column Count/Sum/Average.
- **Thumbnails:** `DocumentThumbnails.render(path, width:)` draws the first page of any supported file as a PNG. Given a saved `position:`, it draws the page reading resumes on. The Word and text readers report the paragraph or line at the top (`PositionKeys.paragraph`, `PositionKeys.line`) for this.
- **PowerPoint (.pptx):** `SlideDeckController`, `SlideDeckView` and `SlideNavigationBar`. Titles, paragraphs, tables and pictures; search.
- **Text (.txt, .md):** `TextDocumentController` and `TextDocumentView`. UTF-8 with a Latin-1 fallback, binary-file check, search.
- **Shared:** `DocumentFormat` (from extension, path or MIME type), `ZipSafetyGuard` for Office files, reading positions as JSON-safe maps (`ReadingPosition`, `PositionKeys`), typed load errors (`DocumentLoadError`), and `testing.dart` builders for in-memory test documents.
- **Platforms:** Android, iOS, macOS, Windows and Linux. Web is not supported yet.
