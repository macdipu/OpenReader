import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/platform_info.dart';

/// Full screen for a reader: the app bar and bottom toolbar hide and, on
/// Android, so do the system bars. Ended on close.
mixin ReaderFullscreen on GetxController {
  final isFullscreen = false.obs;
  /// True when this reader lives in a workspace tab rather than its own
  /// route: leaving it then closes the tab, and Esc never closes the document.
  bool embedded = false;

  /// Told when full screen starts or ends; a workspace tab uses it to hide the tab strip and sidebar too.
  void Function(bool fullscreen)? fullscreenListener;

  /// What "leave the reader" does when [embedded] (close the tab).
  void Function()? exitHandler;

  /// Leaves the reader: pops the route, or closes the tab it lives in.
  void exitReader() {
    if (embedded) {
      exitHandler?.call();
    } else {
      Get.back<void>();
    }
  }

  /// Esc with nothing left to dismiss (full screen and search are already
  /// closed): leaves a routed reader, does nothing in a tab.
  void escapeReader() {
    if (!embedded) exitReader();
  }


  void toggleFullscreen() => setFullscreen(!isFullscreen.value);

  void setFullscreen(bool value) {
    if (isFullscreen.value == value) return;
    isFullscreen.value = value;
    fullscreenListener?.call(value);
    onFullscreenChanged(value);
    // System bars exist only on Android; desktop embedders don't implement
    // this call and would throw.
    if (!PlatformInfo.isAndroid) return;
    unawaited(SystemChrome.setEnabledSystemUIMode(value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge));
  }

  /// For a reader that tidies up on entering or leaving full screen.
  void onFullscreenChanged(bool fullscreen) {}

  @override
  void onClose() {
    setFullscreen(false);
    super.onClose();
  }
}
