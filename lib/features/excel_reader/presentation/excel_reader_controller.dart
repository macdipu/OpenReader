import 'dart:io';

import 'package:universal_document_viewer/sheets.dart';

import '../../../core/presentation/controllers/sheet_reader_controller.dart';

export 'package:universal_document_viewer/sheets.dart' show CellMatch;

/// Drives the Excel reader (BRD §9.12, ODF-015/016, ODF-008 for Excel):
/// universal_document_viewer's [SpreadsheetController] reads the workbook (hidden
/// sheets left out) and [SheetGrid] shows it; [SheetReaderController] adds
/// OpenReader's saved position, favourites and error wording.
class ExcelReaderController extends SheetReaderController {
  ExcelReaderController({required super.document, super.recentRepository, super.interactions});

  @override
  Future<void> loadInto(SpreadsheetController controller, File file) async =>
      controller.loadXlsx(await file.readAsBytes());
}
