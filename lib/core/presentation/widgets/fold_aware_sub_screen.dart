import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// Whether [feature] should split the layout: a hinge, or a fold that is not
/// lying flat. A foldable opened all the way out (a Galaxy Z Fold unfolded,
/// a Pixel Fold) reports a flat fold, but it is one big screen to the user.
bool separatesScreen(DisplayFeature feature) =>
    !(feature.type == DisplayFeatureType.fold && feature.state == DisplayFeatureState.postureFlat);

/// Keeps [child] on one side of a hinge or half-open fold:
///
/// - a vertical hinge or fold (a Surface Duo, a Fold in book posture): the
///   child fills one side and nothing sits under the crease;
/// - a horizontal fold (a Flip half open, a Fold in tabletop posture): the
///   child takes the top half, leaving the bottom half for controls.
///
/// A flat fold, and any device without display features, is untouched.
class FoldAwareSubScreen extends StatelessWidget {
  final Widget child;

  const FoldAwareSubScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final features = media.displayFeatures.where(separatesScreen).toList();
    return MediaQuery(
      data: media.copyWith(displayFeatures: features),
      child: DisplayFeatureSubScreen(child: child),
    );
  }
}
