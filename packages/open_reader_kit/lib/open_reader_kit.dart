/// Open and read PDF, Word (.docx), Excel (.xlsx), CSV, PowerPoint (.pptx)
/// and text documents.
///
/// Import the engine you need; they're separate libraries because their
/// names overlap (e.g. both the Word and spreadsheet models have a
/// `Border`):
///
/// ```dart
/// import 'package:open_reader_kit/pdf.dart';
/// import 'package:open_reader_kit/docx.dart';
/// import 'package:open_reader_kit/docx_core.dart';
/// import 'package:open_reader_kit/excel.dart' as xls;
/// ```
///
/// OpenReader's own readers (slides, spreadsheet grid, text, ZIP safety)
/// move in next - CR-OPENREADER-KIT Phase B.
library;
