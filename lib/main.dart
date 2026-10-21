import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/flavours/app_flavour.dart';
import 'app/views/app.dart';
import 'core/presentation/utils/platform_info.dart';
import 'core/presentation/utils/screen_utils.dart';
import 'services/platform_integration/launch_arguments.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop "Open with OpenReader" / `openreader file.pdf` hands the file over
  // as a command-line argument.
  LaunchArguments.files = args.where((a) => !a.startsWith('-')).toList();

  // Phones stay portrait-only; tablets and desktop windows rotate/resize freely.
  if (PlatformInfo.isMobile && _isPhone()) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  await bootstrap(() => const MyApp());
}

bool _isPhone() {
  final view = ui.PlatformDispatcher.instance.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  return shortestSide < ScreenUtils.mediumBreakpoint;
}
