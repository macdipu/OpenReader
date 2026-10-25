import 'package:universal_document_viewer/universal_document_viewer.dart';
import 'package:universal_document_viewer/spreadsheet.dart';

import '../../../core/presentation/controllers/sheet_reader_controller.dart';

export 'package:universal_document_viewer/spreadsheet.dart' show CellMatch;

/// Drives the CSV reader (BRD §9.15, ODF-020, ODF-008 for CSV):
/// universal_document_viewer's [SpreadsheetController] parses the file (off the UI
/// isolate) and [SpreadsheetView] shows it;
/// [SheetReaderController] adds OpenReader's saved position, favourites and
/// error wording. CSV has one implicit sheet, so no sheet tabs.
class CsvReaderController extends SheetReaderController {
  CsvReaderController({required super.document, super.recentRepository, super.interactions});

  /// See [SpreadsheetController.maxCsvBytes].
  static const int maxBytes = SpreadsheetController.maxCsvBytes;

  @override
  DocumentFormat get format => DocumentFormat.csv;

  /// One sheet, so no sheet index.
  @override
  ReadingPosition positionToSave(ReadingPosition position) =>
      Map.of(position)..remove(PositionKeys.sheetIndex);
}
