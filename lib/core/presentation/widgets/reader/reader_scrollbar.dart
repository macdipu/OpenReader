import 'package:flutter/material.dart';

import '../../utils/platform_info.dart';

/// Visible, draggable scrollbars for a reader, on desktop only: a vertical one, and for wide
/// content (spreadsheets) a horizontal one as well.
///
/// They sit in their own gutters beside the content (never over it), reflect the scroll
/// position and document length, and work alongside the mouse wheel. On Android and iOS this
/// returns [child] unchanged, so touch scrolling is exactly what it was.
class ReaderScrollbar extends StatelessWidget {
  /// The controller of the vertical scrollable inside [child].
  final ScrollController controller;

  /// The controller of a horizontal scrollable inside [child], when it has one.
  final ScrollController? horizontalController;

  final Widget child;

  /// Width of the vertical bar's gutter (and height of the horizontal one's).
  static const double gutter = 14;

  const ReaderScrollbar({super.key, required this.controller, this.horizontalController, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isDesktop) return child;
    final horizontal = horizontalController;
    Widget content = Padding(
      padding: EdgeInsets.only(right: gutter, bottom: horizontal == null ? 0 : gutter),
      child: child,
    );
    if (horizontal != null) {
      content = Scrollbar(
        controller: horizontal,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: 10,
        radius: const Radius.circular(5),
        scrollbarOrientation: ScrollbarOrientation.bottom,
        notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
        child: content,
      );
    }
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 10,
      radius: const Radius.circular(5),
      // The vertical scrollable may sit under a horizontal one when zoomed in.
      notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
      child: content,
    );
  }
}
