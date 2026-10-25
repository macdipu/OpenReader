import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/platform_info.dart';

/// Full screen for a reader: the app bar and bottom toolbar hide and, on
/// Android, so do the system bars. Ended on close.
mixin ReaderFullscreen on GetxController {
  final isFullscreen = false.obs;

  void toggleFullscreen() => setFullscreen(!isFullscreen.value);

  void setFullscreen(bool value) {
    if (isFullscreen.value == value) return;
    isFullscreen.value = value;
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
