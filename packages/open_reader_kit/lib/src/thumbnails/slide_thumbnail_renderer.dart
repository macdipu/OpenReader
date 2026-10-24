import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../slides/pptx_parser.dart';
import '../slides/slide_deck_view.dart';
import 'offscreen_render.dart';
import 'thumbnail_renderer.dart';
import 'thumbnail_sources.dart';

/// Slide 1 of a `.pptx`, drawn by the reader's own [SlideCard] in the
/// presentation's slide shape (16:9, 4:3, ...).
class SlideThumbnailRenderer implements ThumbnailRenderer {
  const SlideThumbnailRenderer();

  /// The slide's logical width: roomy enough for the card's text sizes to
  /// sit on it as they do in the reader.
  static const double _slideWidth = 560;

  @override
  Future<ui.Image?> render(String path, {required int width}) async {
    final deck = await parseOfficeFile(path, _firstSlide);
    if (deck == null || deck.slides.isEmpty) return null;
    final aspect = (deck.slideHeight / deck.slideWidth).clamp(0.25, 4.0);
    return renderOffscreen(
      SlideCard(slide: deck.slides.first, number: 1),
      size: Size(_slideWidth, _slideWidth * aspect),
      width: width,
    );
  }

  /// Just the first slide (and the slide size) comes back from the
  /// parsing isolate, not every slide's pictures.
  static PptxPresentation _firstSlide(Uint8List bytes) {
    final deck = PptxParser.parse(bytes);
    return PptxPresentation(deck.slides.take(1).toList(), slideWidth: deck.slideWidth, slideHeight: deck.slideHeight);
  }
}
