/// Word (.docx): [WordDocumentView] driven by a [WordDocumentController],
/// on open_reader_kit's own engine (`word.dart`: [DocxReader] and the
/// [WordDocument] model).
library;

export 'src/engines/word/docx_reader.dart';
export 'src/engines/word/word_model.dart';
export 'src/word/word_document_controller.dart';
export 'src/word/word_document_layout.dart';
export 'src/word/word_document_view.dart';
export 'src/word/word_pagination.dart' show WordPage, WordPagination;
export 'src/word/word_search_controller.dart';
export 'src/word/word_widgets.dart' show WordBlockView, WordScope;
