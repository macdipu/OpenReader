import 'dart:ui' as ui;

import '../engines/pdfium/pdf_engine.dart';
import 'thumbnail_renderer.dart';

/// Page 1 of a PDF, whole, as PDFium draws it. A password-protected or
/// damaged file fails to open and gets no thumbnail.
class PdfThumbnailRenderer implements ThumbnailRenderer {
  const PdfThumbnailRenderer();

  @override
  Future<ui.Image?> render(String path, {required int width}) async {
    final document = await PdfiumDocument.openFile(path);
    try {
      if (document.pageCount == 0 || document.pageSizes.first.width <= 0) return null;
      final page = await document.renderThumbnail(0, width: width);
      return await page.toImage();
    } finally {
      await document.close();
    }
  }
}
