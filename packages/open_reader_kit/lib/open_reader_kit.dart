/// Open and read PDF, Word (.docx), Excel (.xlsx), CSV, PowerPoint (.pptx)
/// and text documents.
///
/// This library has what every format shares: format detection, the ZIP
/// safety check for Office files and text decoding. Each format has its own
/// library:
///
/// ```dart
/// import 'package:open_reader_kit/pdf.dart';
/// import 'package:open_reader_kit/docx.dart';
/// import 'package:open_reader_kit/slides.dart';
/// import 'package:open_reader_kit/sheets.dart';
/// import 'package:open_reader_kit/text.dart';
/// ```
///
/// Or let [DocumentViewer] pick the reader for any supported file:
///
/// ```dart
/// DocumentViewer.file(path, onPositionChanged: save, initialPosition: saved)
/// ```
library;

export 'src/common/document_format.dart';
export 'src/common/reader_contract.dart';
export 'src/common/text_decoding.dart';
export 'src/common/zip_safety_guard.dart';
export 'src/viewer/document_viewer.dart';
