

import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';

/// Tells the reader no text was found on a page that OCR just read.
void showNoTextFound() => CustomSnackbar.show(message: 'No text found on this page', type: SnackbarType.warning);

