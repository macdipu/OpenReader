import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whether a file sits inside the app's own cache or files folders (files other apps shared into
/// OpenReader, picked files copied in). Those are readable without any storage permission, so the
/// permission check applies to shared-storage paths only.
class AppPrivatePaths {
  AppPrivatePaths({Future<List<String>> Function()? directories}) : _custom = directories;

  /// A fixed set of folders, for tests.
  AppPrivatePaths.fixed(List<String> directories) : this(directories: () async => directories);

  static final AppPrivatePaths instance = AppPrivatePaths();

  final Future<List<String>> Function()? _custom;
  List<String>? _cached;

  /// Set by [_fromPlatform] when a folder could not be resolved; such a result is not remembered,
  /// so one failed lookup does not leave that folder non-private for the rest of the session.
  bool _incomplete = false;

  Future<List<String>> _directories() {
    final custom = _custom;
    return custom != null ? custom() : _fromPlatform();
  }

  Future<List<String>> _fromPlatform() async {
    final found = <String>[];
    var incomplete = false;
    for (final lookup in [getTemporaryDirectory, getApplicationSupportDirectory, getApplicationDocumentsDirectory]) {
      try {
        found.add((await lookup()).path);
      } catch (_) {
        // A folder that cannot be resolved does not count as private this time; it is retried.
        incomplete = true;
      }
    }
    _incomplete = incomplete;
    return found;
  }

  Future<bool> contains(String path) async {
    var dirs = _cached;
    if (dirs == null) {
      try {
        dirs = await _directories();
      } catch (_) {
        return false;
      }
      if (!_incomplete) _cached = dirs;
    }
    // Compare real locations only: a symlink inside a private folder that points out is not private,
    // and one outside that points in is.
    final candidate = _canonical(path);
    for (final dir in dirs) {
      if (p.isWithin(_canonical(dir), candidate)) return true;
    }
    return false;
  }

  /// [path] with symbolic links resolved as far as it exists (the rest, e.g. a file not created yet,
  /// is appended as written).
  static String _canonical(String path) {
    var current = p.normalize(p.absolute(path));
    final rest = <String>[];
    while (true) {
      try {
        final type = FileSystemEntity.typeSync(current, followLinks: true);
        if (type != FileSystemEntityType.notFound) {
          final real = type == FileSystemEntityType.directory
              ? Directory(current).resolveSymbolicLinksSync()
              : File(current).resolveSymbolicLinksSync();
          return p.normalize(p.joinAll([real, ...rest.reversed]));
        }
      } catch (_) {
        break;
      }
      final parent = p.dirname(current);
      if (parent == current) break;
      rest.add(p.basename(current));
      current = parent;
    }
    return p.normalize(p.absolute(path));
  }
}
