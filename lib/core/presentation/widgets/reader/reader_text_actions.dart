import 'package:flutter/material.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';

import '../snackbar/custom_snackbar.dart';

/// "Copy all text" for a reader's ⋮ menu (CR-READER-SELECT-OCR SO-06).
///
/// Copying a selection and Select all are not here on purpose: the system
/// gives them (the selection toolbar on a long press on mobile; right click,
/// Ctrl or Cmd+C and +A on desktop), and universal_document_viewer's views
/// use it. A whole document is the one thing no system toolbar offers.
List<PopupMenuEntry<T>> readerCopyAllMenuItems<T>(T copyAll) => [
  PopupMenuItem(value: copyAll, child: const Text('Copy all text')),
  const PopupMenuDivider(),
];

/// Copies all of [controller]'s document text and says how it went.
Future<void> runReaderCopyAll(DocumentController controller) async {
  final text = await controller.allText();
  if (text.isEmpty) {
    CustomSnackbar.show(message: 'This document has no text to copy', type: SnackbarType.warning);
    return;
  }
  final ok = await controller.copyAllText();
  CustomSnackbar.show(
    message: ok ? 'All text copied' : 'Could not copy: the clipboard is not available',
    type: ok ? SnackbarType.success : SnackbarType.error,
    duration: const Duration(seconds: 2),
  );
}
