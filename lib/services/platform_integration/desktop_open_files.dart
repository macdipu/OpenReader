import 'package:flutter/services.dart';

/// macOS only: Finder hands documents to the app as an Apple Event, which
/// `AppDelegate.swift` forwards over this channel (Windows and Linux pass the
/// path as a command-line argument, see [LaunchArguments]).
class DesktopOpenFiles {
  DesktopOpenFiles._();

  static const _channel = MethodChannel('openreader/open_files');

  /// Calls [onFiles] for files opened while the app is running, then returns
  /// the ones that launched it.
  static Future<List<String>> listen(void Function(List<String> files) onFiles) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFiles') onFiles(List<String>.from(call.arguments as List));
    });
    try {
      return List<String>.from(await _channel.invokeMethod<List<Object?>>('takeInitialFiles') ?? const []);
    } on MissingPluginException {
      return const [];
    }
  }
}
