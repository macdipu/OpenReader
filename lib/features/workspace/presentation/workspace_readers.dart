import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../csv_reader/presentation/csv_reader_controller.dart';
import '../../csv_reader/presentation/csv_reader_view.dart';
import '../../excel_reader/presentation/excel_reader_controller.dart';
import '../../excel_reader/presentation/excel_reader_view.dart';
import '../../pdf_reader/presentation/pdf_reader_controller.dart';
import '../../pdf_reader/presentation/pdf_reader_view.dart';
import '../../powerpoint_reader/presentation/powerpoint_reader_controller.dart';
import '../../powerpoint_reader/presentation/powerpoint_reader_view.dart';
import '../../text_reader/presentation/text_reader_controller.dart';
import '../../text_reader/presentation/text_reader_view.dart';
import '../../word_reader/presentation/word_reader_controller.dart';
import '../../word_reader/presentation/word_reader_view.dart';
import '../../../core/presentation/controllers/reader_fullscreen.dart';
import 'workspace_controller.dart';

/// Creates the reader controller behind a workspace tab, registered under the
/// tab's id so several of the same kind can live side by side, and tells it
/// that it is embedded: leaving closes the tab, Esc does not close it.
// The explicit type arguments on Get.put matter: without them Dart infers the type from the
// parameter of embed() and registers every controller as a ReaderFullscreen.
void registerTabReader(WorkspaceTab tab, WorkspaceController workspace) {
  final document = tab.document;
  void embed(ReaderFullscreen controller) {
    controller
      ..embedded = true
      ..exitHandler = () => workspace.close(tab.id);
  }

  switch (document.category) {
    case DocumentCategory.pdf:
      embed(Get.put<PdfReaderController>(PdfReaderController(document: document), tag: tab.id));
    case DocumentCategory.word:
      embed(Get.put<WordReaderController>(WordReaderController(document: document), tag: tab.id));
    case DocumentCategory.excel:
      embed(Get.put<ExcelReaderController>(ExcelReaderController(document: document), tag: tab.id));
    case DocumentCategory.csv:
      embed(Get.put<CsvReaderController>(CsvReaderController(document: document), tag: tab.id));
    case DocumentCategory.text:
      embed(Get.put<TextReaderController>(TextReaderController(document: document), tag: tab.id));
    case DocumentCategory.powerpoint:
      embed(Get.put<PowerPointReaderController>(PowerPointReaderController(document: document), tag: tab.id));
    case DocumentCategory.unknown:
      break;
  }
}

/// Removes the tab's reader controller (which saves the reading position).
void disposeTabReader(WorkspaceTab tab) {
  final id = tab.id;
  switch (tab.document.category) {
    case DocumentCategory.pdf:
      Get.delete<PdfReaderController>(tag: id, force: true);
    case DocumentCategory.word:
      Get.delete<WordReaderController>(tag: id, force: true);
    case DocumentCategory.excel:
      Get.delete<ExcelReaderController>(tag: id, force: true);
    case DocumentCategory.csv:
      Get.delete<CsvReaderController>(tag: id, force: true);
    case DocumentCategory.text:
      Get.delete<TextReaderController>(tag: id, force: true);
    case DocumentCategory.powerpoint:
      Get.delete<PowerPointReaderController>(tag: id, force: true);
    case DocumentCategory.unknown:
      break;
  }
}

/// The reader for a tab, reading its own controller by tag.
Widget buildTabReader(WorkspaceTab tab) {
  final key = ValueKey('reader-${tab.id}');
  return switch (tab.document.category) {
    DocumentCategory.pdf => PdfReaderView(key: key, tabTag: tab.id),
    DocumentCategory.word => WordReaderView(key: key, tabTag: tab.id),
    DocumentCategory.excel => ExcelReaderView(key: key, tabTag: tab.id),
    DocumentCategory.csv => CsvReaderView(key: key, tabTag: tab.id),
    DocumentCategory.text => TextReaderView(key: key, tabTag: tab.id),
    DocumentCategory.powerpoint => PowerPointReaderView(key: key, tabTag: tab.id),
    DocumentCategory.unknown => const SizedBox.shrink(),
  };
}
