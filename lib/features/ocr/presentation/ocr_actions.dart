import 'package:universal_document_viewer/pdf.dart';

import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';

/// Tells the reader no text was found on a page that OCR just read.
void showNoTextFound() => CustomSnackbar.show(message: 'No text found on this page', type: SnackbarType.warning);

/// "Extract text from this page" from the ⋮ menu: reads the page in view
/// (also useful on a page that has text and pictures) and says how it went.
Future<void> extractPageText(PdfController pdf) async {
  final page = pdf.currentPage - 1;
  final found = await pdf.recognizePage(page);
  if (found) {
    CustomSnackbar.show(message: 'Text ready to select', type: SnackbarType.success, duration: const Duration(seconds: 2));
  } else if (pdf.ocrStatusOf(page) == PdfOcrStatus.failed) {
    CustomSnackbar.show(message: 'Could not read the text on this page', type: SnackbarType.error);
  } else if (pdf.ocrStatusOf(page) == PdfOcrStatus.done) {
    showNoTextFound();
  }
}
