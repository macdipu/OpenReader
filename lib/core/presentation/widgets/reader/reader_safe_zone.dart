import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import '../fold_aware_sub_screen.dart';

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
/// On a folding device the column stays on one side of a hinge or fold that
/// separates the screen (a Surface Duo, a Fold in book posture), and in
/// tabletop posture (a Flip half-open, a horizontal fold) it sits in the top
/// half, leaving the bottom half for the reader's toolbar.
///
/// The widget tree is the same at every width, so resizing the window (or
/// folding a device) never rebuilds the reader and loses its position.
class ReaderSafeZone extends StatelessWidget {
  final ReaderContent kind;
  final Widget child;

  /// Windows narrower than this fill the width.
  static const double wideBreakpoint = 760;

  const ReaderSafeZone({super.key, required this.kind, required this.child});

  /// The width the column gets in a window [available] wide.
  static double columnWidth(ReaderContent kind, double available) {
    if (available < wideBreakpoint) return available;
    return available < kind.maxWidth ? available : kind.maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    return FoldAwareSubScreen(
      child: LayoutBuilder(builder: (context, constraints) {
        final width = columnWidth(kind, constraints.maxWidth);
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
      }),
    );
  }
}
