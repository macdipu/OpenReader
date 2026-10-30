import 'package:flutter/material.dart';

import '../../utils/platform_info.dart';

/// A visible, draggable vertical scrollbar for a reader, on desktop only.
///
/// It sits in its own gutter beside the content (never over it), reflects the
/// scroll position and document length, and works alongside the mouse wheel.
/// On Android and iOS this returns [child] unchanged, so touch scrolling is
/// exactly what it was.
class ReaderScrollbar extends StatelessWidget {
  /// The controller of the vertical scrollable inside [child].
  final ScrollController controller;
  final Widget child;

  /// Width reserved for the bar.
  static const double gutter = 14;

  const ReaderScrollbar({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isDesktop) return child;
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 10,
      radius: const Radius.circular(5),
      // The vertical scrollable may sit under a horizontal one when zoomed in.
      notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.only(right: gutter),
        child: child,
      ),
    );
  }
}
