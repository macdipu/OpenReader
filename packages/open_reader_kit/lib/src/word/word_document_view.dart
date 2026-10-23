import 'package:flutter/material.dart';

import '../engines/docx/viewer/docx_file_viewer.dart';
import 'word_document_controller.dart';

/// A `.docx` rendered as one continuous scrolling document, with search
/// highlights from [WordDocumentController.searchController]. Show it once
/// [WordDocumentController.validatedBytes] is set.
class WordDocumentView extends StatelessWidget {
  const WordDocumentView({super.key, required this.controller, this.padding = const EdgeInsets.all(16)});

  final WordDocumentController controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // Only the document's own vertical scroll: wide tables scroll
      // horizontally inside it and would overwrite the position.
      onNotification: (notification) {
        if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
          controller.onScrollOffsetChanged(notification.metrics.pixels);
        }
        return false;
      },
      // The engine's scroll view has no controller of its own, so it adopts
      // this one - on every platform, not only mobile - which is how the
      // position is restored.
      child: PrimaryScrollController(
        controller: controller.scrollController,
        automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
        child: Padding(
          padding: padding,
          child: DocxView(
            bytes: controller.validatedBytes!,
            // Continuous, not the default paged layout: paged mode cuts
            // content into fixed-height A4 boxes by *estimated* height and
            // clips whatever overflows, which hid text at page breaks on
            // phones (BUG-OPENREADER-WORD-PAGEBREAK).
            config: const DocxViewConfig(pageMode: DocxPageMode.continuous),
            searchController: controller.searchController,
            onLoaded: controller.onDocumentLoaded,
            onError: controller.onLoadError,
          ),
        ),
      ),
    );
  }
}
