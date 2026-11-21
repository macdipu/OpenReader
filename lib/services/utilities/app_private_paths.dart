import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whether a file sits inside the app's own cache or files folders (files other apps shared into
/// OpenReader, picked files copied in). Those are readable without any storage permission, so the
/// permission check applies to shared-storage paths only.
class AppPrivatePaths {
  AppPrivatePaths({Future<List<String>> Function()? directories}) : _directories = directories ?? _fromPlatform;

  /// A fixed set of folders, for tests.
  AppPrivatePaths.fixed(List<String> directories) : this(directories: () async => directories);

  static final AppPrivatePaths instance = AppPrivatePaths();

  final Future<List<String>> Function() _directories;
  List<String>? _cached;

  static Future<List<String>> _fromPlatform() async {
    final found = <String>[];
    for (final lookup in [getTemporaryDirectory, getApplicationSupportDirectory, getApplicationDocumentsDirectory]) {
      try {
        found.add((await lookup()).path);
      } catch (_) {
        // A folder that cannot be resolved just does not count as private.
      }
    }
    return found;
  }

  Future<bool> contains(String path) async {
    List<String> dirs;
    try {
      dirs = _cached ??= await _directories();
    } catch (_) {
      return false;
    }
    final candidates = {p.normalize(path), _canonical(path)};
    for (final dir in dirs) {
      for (final root in {p.normalize(dir), _canonical(dir)}) {
        for (final candidate in candidates) {
          if (p.isWithin(root, candidate)) return true;
        }
      }
    }
    return false;
  }

  static String _canonical(String path) {
    try {
      return File(path).existsSync() ? File(path).resolveSymbolicLinksSync() : Directory(path).resolveSymbolicLinksSync();
    } catch (_) {
      return p.normalize(path);
    }
  }
}
