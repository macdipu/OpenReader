import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../controllers/reader_rotation.dart';

/// A reader's body, turned by the reader's [ReaderRotation]. Always in the tree (a quarter turn of 0
/// draws nothing extra), so turning never rebuilds the document or loses the reading position. Touches
/// and scrolling follow the turn.
class ReaderRotated extends StatelessWidget {
  const ReaderRotated({super.key, required this.controller, required this.child});

  final ReaderRotation controller;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Obx(() => RotatedBox(quarterTurns: controller.quarterTurns.value, child: child));
}
