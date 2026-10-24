import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engines/word/docx_reader.dart';
import '../engines/word/word_model.dart';
import '../word/word_document_layout.dart';
import '../word/word_document_view.dart';
import '../word/word_pagination.dart';
import '../word/word_paragraph_styler.dart';
import '../word/word_search_controller.dart';
import '../word/word_widgets.dart';
import 'offscreen_render.dart';
import 'thumbnail_renderer.dart';
import 'thumbnail_sources.dart';

/// Page 1 of a `.docx` as the print layout shows it: paginated by
/// [WordPaginator] and drawn by the same [WordPageView] - header, footer,
/// margins and the section's page size included.
class WordThumbnailRenderer implements ThumbnailRenderer {
  const WordThumbnailRenderer();

  /// Body blocks kept for paginating: far more than a first page holds, so
  /// a long document isn't paginated (or sent over from the parsing
  /// isolate) in full.
  static const int _maxBlocks = 150;

  @override
  Future<ui.Image?> render(String path, {required int width}) async {
    final document = await parseOfficeFile(path, _firstBlocks);
    if (document == null) return null;
    final layout = WordDocumentLayout(document);
    final styler = WordParagraphStyler(
      scheme: WordPageView.paper.colorScheme,
      linkColor: document.linkColor,
      pageNumber: 1,
      pageCount: 1,
    );
    final pages = WordPaginator(layout, WordMeasurer(styler)).paginate().pages;
    final page = pages.first;
    final search = WordSearchController();
    try {
      return await renderOffscreen(
        WordScope(
          layout: layout,
          search: search,
          onLink: (_) {},
          onNote: (_) {},
          anchors: <int, BuildContext>{},
          child: WordPageInfo(
            number: 1,
            count: pages.length,
            // A page whose content can't be split grows past its size;
            // the thumbnail shows its top.
            child: OverflowBox(alignment: Alignment.topCenter, maxHeight: double.infinity, child: WordPageView(page)),
          ),
        ),
        size: Size(page.width, page.height),
        width: width,
        theme: WordPageView.paper,
      );
    } finally {
      search.dispose();
    }
  }

  /// The document with its body cut to [_maxBlocks] and its notes (which
  /// start on a page after the body) left out.
  static WordDocument _firstBlocks(Uint8List bytes) {
    final document = DocxReader.read(bytes);
    if (document.body.length <= _maxBlocks && document.footnotes.isEmpty && document.endnotes.isEmpty) return document;
    return WordDocument(
      body: document.body.take(_maxBlocks).toList(),
      sections: document.sections,
      images: document.images,
      linkColor: document.linkColor,
    );
  }
}
