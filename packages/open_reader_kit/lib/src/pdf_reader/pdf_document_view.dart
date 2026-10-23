import 'package:flutter/material.dart';

import '../engines/pdf/viewer/pdfrx.dart';
import 'pdf_document_controller.dart';

/// A PDF file shown with [controller]'s layout, search highlights and page
/// tracking.
class PdfDocumentView extends StatelessWidget {
  const PdfDocumentView({
    super.key,
    required this.path,
    required this.controller,
    this.passwordProvider,
    this.backgroundColor,
    this.onTap,
    this.errorBuilder,
  });

  final String path;
  final PdfDocumentController controller;

  /// Asked for a password for an encrypted PDF: first an empty password is
  /// tried automatically, then this is called once per attempt until it
  /// returns null (give up) or the password works.
  final PdfPasswordProvider? passwordProvider;
  final Color? backgroundColor;

  /// A tap on a page; return true if it was handled.
  final bool Function()? onTap;

  /// Shown instead of the document when it fails to open.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final searcher = controller.textSearcher;
        return PdfViewer.file(
          path,
          controller: controller.pdfController,
          initialPageNumber: controller.initialPageNumber,
          passwordProvider: passwordProvider,
          params: PdfViewerParams(
            backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
            onViewerReady: controller.onViewerReady,
            onPageChanged: controller.onPageChanged,
            pagePaintCallbacks: searcher == null ? null : [searcher.pageTextMatchPaintCallback],
            layoutPages: controller.viewMode == PdfReaderViewMode.horizontal ? pdfHorizontalLayout : null,
            onGeneralTap: onTap == null ? null : (context, viewerController, details) => onTap!(),
            errorBannerBuilder: errorBuilder == null
                ? null
                : (context, error, stackTrace, documentRef) => errorBuilder!(context, error),
          ),
        );
      },
    );
  }
}
