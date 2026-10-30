import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// What a reader shows, which decides how wide its reading column may get.
enum ReaderContent {
  /// PDF pages: A4-ish proportions, centred with a margin of backdrop.
  page(920),

  /// Word documents: about an A4 page at screen size plus its gutters.
  document(880),

  /// Plain text and Markdown: a comfortable line length (about 80 characters).
  text(780),

  /// Slides: wider, the slide keeps its own aspect ratio inside.
  slides(1180);

  /// Widest the reading column gets, in logical pixels.
  final double maxWidth;
  const ReaderContent(this.maxWidth);
}

/// Keeps a reader's content in a readable column on wide windows (desktop,
/// large tablets) instead of stretching it across the whole screen, with the
/// rest left as a quiet backdrop like a desktop document viewer. Phones and
/// narrow windows are untouched: below [wideBreakpoint] the content fills the
/// width.
///
/// The widget tree is the same at every width, so resizing the window (or
/// folding a device) never rebuilds the reader and loses its position.
class ReaderSafeZone extends StatelessWidget {
  final ReaderContent kind;
  final Widget child;

  /// Windows narrower than this fill the width.
  static const double wideBreakpoint = 760;

  const ReaderSafeZone({super.key, required this.kind, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth;
      final width = available < wideBreakpoint ? available : (available < kind.maxWidth ? available : kind.maxWidth);
      return ColoredBox(
        color: context.surfaceContainerLow,
        child: Center(
          child: SizedBox(
            width: width,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        ),
      );
    });
  }
}
