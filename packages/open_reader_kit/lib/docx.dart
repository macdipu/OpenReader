/// Word (.docx): [WordDocumentView] driven by a [WordDocumentController],
/// plus the underlying engine (`DocxView`, `DocxSearchController`).
///
/// The engine was originally docx_file_viewer 1.0.4 (see NOTICE.md); now
/// maintained in open_reader_kit.
library;

export 'src/engines/docx/viewer/docx_file_viewer.dart';
export 'src/word/word_document_controller.dart';
export 'src/word/word_document_view.dart';
