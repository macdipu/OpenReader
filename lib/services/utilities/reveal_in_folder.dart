import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/presentation/utils/platform_info.dart';

/// Shows [path] in the system file manager with the file selected (Explorer, Finder), or its
/// folder on Linux where file managers have no common "select this file" command.
Future<void> revealInFolder(String path) async {
  if (PlatformInfo.isWindows) {
    // `explorer /select,<path>` wants the comma attached to the switch and a backslash path.
    await Process.run('explorer', ['/select,${path.replaceAll('/', r'\')}']);
  } else if (PlatformInfo.isMacOS) {
    await Process.run('open', ['-R', path]);
  } else if (PlatformInfo.isLinux) {
    await Process.run('xdg-open', [p.dirname(path)]);
  }
}
