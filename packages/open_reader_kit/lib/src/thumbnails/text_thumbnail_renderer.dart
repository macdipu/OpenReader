import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../common/text_decoding.dart';
import '../text/text_document_controller.dart';
import 'offscreen_render.dart';
import 'thumbnail_renderer.dart';
import 'thumbnail_sources.dart';

/// The first lines of a text file on a white, A4-shaped page, wrapped as
/// the text reader wraps them. Only the start of the file is read; a file
/// the reader would refuse (too large, or binary) gets no thumbnail.
class TextThumbnailRenderer implements ThumbnailRenderer {
  const TextThumbnailRenderer();

  /// A4 at a logical width where 9 px text reads as a printed page's.
  static const Size _page = Size(420, 594);
  static const int _maxLines = 80;

  @override
  Future<ui.Image?> render(String path, {required int width}) async {
    final head = await readTextHead(path, maxBytes: TextDocumentController.maxBytes);
    if (head == null || TextDocumentController.looksBinary(head)) return null;
    final lines = decodeTextBytes(head).split('\n').take(_maxLines).join('\n');
    return renderOffscreen(_TextPage(lines), size: _page, width: width);
  }
}

class _TextPage extends StatelessWidget {
  const _TextPage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        text,
        overflow: TextOverflow.clip,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9, height: 1.35, color: theme.colorScheme.onSurface),
      ),
    );
  }
}
