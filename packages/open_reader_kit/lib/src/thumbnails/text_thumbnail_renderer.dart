import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../common/reader_contract.dart';
import '../common/text_decoding.dart';
import '../text/text_document_controller.dart';
import 'offscreen_render.dart';
import 'thumbnail_renderer.dart';
import 'thumbnail_sources.dart';

/// The first lines of a text file on a white, A4-shaped page, wrapped as
/// the text reader wraps them - or, with a saved `line`, the lines from
/// that one on. Only the start of the file is read unless the saved line is
/// past the first; a file the reader would refuse (too large, or binary)
/// gets no thumbnail.
class TextThumbnailRenderer implements ThumbnailRenderer {
  const TextThumbnailRenderer();

  /// A4 at a logical width where 9 px text reads as a printed page's.
  static const Size _page = Size(420, 594);
  static const int _maxLines = 80;

  @override
  Future<ui.Image?> render(String path, {required int width, ReadingPosition? position}) async {
    final line = positionIndex(position, PositionKeys.line) ?? 0;
    final String? lines;
    if (line > 0) {
      lines = await parseTextFile<String?>(
        path,
        maxBytes: TextDocumentController.maxBytes,
        parse: (bytes) => _linesFrom(bytes, line),
      );
    } else {
      final head = await readTextHead(path, maxBytes: TextDocumentController.maxBytes);
      lines = head == null ? null : _linesFrom(head, 0);
    }
    if (lines == null) return null;
    return renderOffscreen(_TextPage(lines), size: _page, width: width);
  }

  /// The page's lines, from [first] on (from the top when the text is
  /// shorter); null for bytes that don't look like text.
  static String? _linesFrom(Uint8List bytes, int first) {
    if (TextDocumentController.looksBinary(bytes)) return null;
    final lines = decodeTextBytes(bytes).split('\n');
    final start = first < lines.length ? first : 0;
    return lines.skip(start).take(_maxLines).join('\n');
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
