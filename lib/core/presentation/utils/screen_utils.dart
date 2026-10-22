import 'package:flutter/widgets.dart';

/// Window-size classes (Material 3 window size classes, by width).
enum ScreenSize {
  /// Phones (< 600dp): single pane, bottom navigation.
  compact,

  /// Large phones / small tablets / narrow desktop windows (600-1023dp).
  medium,

  /// Tablets and desktop windows (>= 1024dp): navigation rail, wide content.
  expanded;

  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;
}

/// Responsive helpers so layout decisions come from the window size, not the
/// platform: a narrow desktop window gets the phone layout and a tablet gets
/// the desktop one.
///
/// Deliberately first-party instead of a design-size scaling package
/// (`flutter_screenutil`): scaling every dp with the window width makes text
/// and controls balloon on a 27" monitor, which is the opposite of what a
/// desktop reader needs. Here content is constrained, not stretched.
class ScreenUtils {
  ScreenUtils._();

  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 1024;

  /// Widest a reading column / list is allowed to grow before it is centered
  /// with margins, so lines stay readable on large windows.
  static const double maxContentWidth = 960;

  /// Widest a single reader page (text, document) may grow.
  static const double maxReaderWidth = 820;

  static ScreenSize sizeForWidth(double width) {
    if (width >= expandedBreakpoint) return ScreenSize.expanded;
    if (width >= mediumBreakpoint) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  static ScreenSize of(BuildContext context) => sizeForWidth(MediaQuery.sizeOf(context).width);

  /// Side margin for page content: tighter on phones, roomier on desktop.
  static double horizontalPadding(BuildContext context) {
    switch (of(context)) {
      case ScreenSize.compact:
        return 16;
      case ScreenSize.medium:
        return 24;
      case ScreenSize.expanded:
        return 32;
    }
  }
}

extension ScreenUtilsContext on BuildContext {
  ScreenSize get screenSize => ScreenUtils.of(this);
  bool get isCompactScreen => screenSize.isCompact;
  bool get isExpandedScreen => screenSize.isExpanded;
  Size get screenDimensions => MediaQuery.sizeOf(this);

  /// [base] grown with the system text size (clamped to 2x), for fixed-size
  /// boxes that hold text - so large text doesn't clip (UX-31).
  double scaledExtent(double base) {
    final factor = MediaQuery.textScalerOf(this).scale(14) / 14;
    return base * factor.clamp(1.0, 2.0);
  }
}

/// Centers [child] and caps its width at [maxWidth] on large windows; a no-op
/// on phones where the screen is already narrower than the cap.
class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentConstraint({super.key, required this.child, this.maxWidth = ScreenUtils.maxContentWidth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
