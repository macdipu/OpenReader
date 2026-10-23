/// PDF: [PdfDocumentView] driven by a [PdfDocumentController], plus the
/// underlying engine (`PdfViewer`, `PdfDocument`, text search, PDFium).
///
/// The engine was originally pdfrx 2.4.8 + pdfrx_engine 0.4.7 +
/// pdfium_dart 0.2.5 + pdfium_flutter 0.2.3 (see NOTICE.md); now maintained
/// in open_reader_kit.
library;

export 'src/engines/pdf/viewer/pdfrx.dart';
export 'src/pdf_reader/pdf_document_controller.dart';
export 'src/pdf_reader/pdf_document_view.dart';
