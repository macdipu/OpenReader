import 'package:flutter/material.dart';

import 'app/flavours/app_flavour.dart';
import 'app/views/app.dart';
import 'services/platform_integration/launch_arguments.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop "Open with OpenReader" / `openreader file.pdf` hands the file over
  // as a command-line argument.
  LaunchArguments.files = args.where((a) => !a.startsWith('-')).toList();

  // No orientation lock: phones rotate to landscape, tablets and foldables
  // follow the posture. The old lock was decided once at start-up from the
  // window then, so a Fold launched folded stayed portrait-locked after it
  // was opened. Layouts adapt to the window size instead (see ScreenUtils).

  await bootstrap(() => const MyApp());
}
