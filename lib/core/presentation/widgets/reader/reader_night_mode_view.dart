import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Draws a reader's content in night mode (UX-33).
///
/// - [paper] content - PDF pages, Word's print layout, page thumbnails - is
///   white whatever the theme, so it's drawn in the light theme (its
///   backdrop too) and inverted, keeping hues (red stays reddish rather
///   than turning cyan).
/// - Otherwise it wraps a whole reader screen - bars and theme-following
///   content - in the app's dark theme; already dark, it's unchanged.
///
/// The filter is always there (identity when off), so toggling doesn't
/// rebuild the content and lose the reading position.
class ReaderNightModeView extends StatelessWidget {
  final bool enabled;
  final bool paper;
  final Widget child;

  const ReaderNightModeView({super.key, required this.enabled, required this.child, this.paper = false});

  static const _identity = ColorFilter.matrix(<double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Inverts lightness, then turns hues back round by 180°.
  static const _invert = ColorFilter.matrix(<double>[
    0.574, -1.430, -0.144, 0, 255, //
    -0.426, -0.430, -0.144, 0, 255, //
    -0.426, -1.430, 0.856, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    if (paper) {
      return ColorFiltered(
        colorFilter: enabled ? _invert : _identity,
        child: Theme(data: enabled ? AppTheme.lightTheme : Theme.of(context), child: child),
      );
    }
    final dark = enabled && Theme.of(context).brightness == Brightness.light;
    return Theme(
      data: dark ? AppTheme.darkTheme : Theme.of(context),
      // Re-seeds the default text style from the theme in force.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
