import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/data/repositories/document_repository_impl.dart';
import '../../core/domain/models/keep_state.dart';
import '../../core/domain/repositories/document_repository.dart';
import '../../core/presentation/utils/logger.dart';

/// What [SharedCopyStore.prune] did.
class SharedCopyPruneResult {
  const SharedCopyPruneResult({required this.removed, required this.freedBytes, required this.remainingBytes});

  final int removed;
  final int freedBytes;
  final int remainingBytes;
}

/// The folder where files other apps shared into OpenReader are copied (Android: app files,
/// `incoming`, written by `MainActivity`), and its clean-up (CR-FILE-RELOCATE).
///
/// A copy is removed only when nothing needs it: it is not in Recents, not a favorite and not kept.
/// The folder is also capped; when it is over the cap the oldest unused copies go first, then the
/// oldest ones that are only in Recents. Kept copies and favorites are never removed here.
///
/// A copy's age is its inode change time, not its modified time: the copy's modified time is set to
/// the source file's, so it says nothing about when the copy was made.
class SharedCopyStore {
  SharedCopyStore({
    DocumentRepository? documents,
    Future<Directory?> Function()? folder,
    DateTime Function()? now,
    this.maxAge = const Duration(days: 7),
    this.capBytes = defaultCapBytes,
    this.grace = const Duration(hours: 1),
  }) : _documents = documents ?? DocumentRepositoryImpl(),
       _folder = folder ?? _platformFolder,
       _now = now ?? DateTime.now;

  /// Matches `MainActivity.INCOMING_DIR`.
  static const folderName = 'incoming';

  static const defaultCapBytes = 500 * 1024 * 1024;

  final DocumentRepository _documents;
  final Future<Directory?> Function() _folder;
  final DateTime Function() _now;

  /// Unused copies older than this are removed.
  final Duration maxAge;

  /// The folder's size above which older copies are removed too.
  final int capBytes;

  /// A copy younger than this is never removed: it may be the file being opened right now.
  final Duration grace;

  static Future<Directory?> _platformFolder() async {
    if (!Platform.isAndroid) return null;
    return Directory(p.join((await getApplicationSupportDirectory()).path, folderName));
  }

  /// Whether [path] is a copy this store manages: a file straight inside the `incoming` folder.
  /// Only Android makes such copies; [android] is for tests.
  static bool isSharedCopy(String path, {bool? android}) =>
      (android ?? Platform.isAndroid) && p.basename(p.dirname(path)) == folderName;

  /// Copies [source] into the folder and returns the copy's path, or null where there is no folder
  /// (not Android). A picked file on Android is already a cache copy the OS may clear, so a file the
  /// user located is moved to somewhere safe the same way a shared one is.
  Future<String?> adopt(File source) async {
    final dir = await _folder();
    if (dir == null) return null;
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, '${source.path.hashCode.toRadixString(16)}_${p.basename(source.path)}'));
    final partial = File('${target.path}.part');
    await source.copy(partial.path);
    await partial.rename(target.path);
    return target.path;
  }

  /// Removes every copy that is not kept or a favorite, and the Recents entries that pointed at them.
  /// Returns the bytes freed. Kept copies and favorites stay.
  Future<int> clear() async {
    final copies = await _copies();
    final protectedPaths = (await _documents.protectedPaths()).fold(
      (_) => <String, CopyProtection>{},
      (paths) => paths,
    );
    var freed = 0;
    for (final copy in copies) {
      if (protectedPaths[copy.file.path] == CopyProtection.kept) continue;
      final indexed = (await _documents.getById(copy.file.path)).fold((_) => null, (document) => document);
      try {
        if (indexed != null) {
          // Drops the file and the row, and with it the Recents entry (ON DELETE CASCADE).
          await _documents.deleteDocument(indexed);
        } else {
          await copy.file.delete();
        }
        freed += copy.size;
      } on FileSystemException catch (e) {
        AppLogger.warning('[COPIES] could not remove ${copy.file.path}: $e');
      }
    }
    return freed;
  }

  Future<List<_Copy>> _copies() async {
    final dir = await _folder();
    if (dir == null || !await dir.exists()) return const [];
    final copies = <_Copy>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        copies.add(_Copy(entity, stat.size, stat.changed));
      } on FileSystemException {
        // Gone while listing.
      }
    }
    return copies;
  }

  /// Bytes used by copies of other apps' files.
  Future<int> usedBytes() async => (await _copies()).fold<int>(0, (sum, copy) => sum + copy.size);

  Future<SharedCopyPruneResult> prune() async {
    final copies = await _copies();
    if (copies.isEmpty) return const SharedCopyPruneResult(removed: 0, freedBytes: 0, remainingBytes: 0);
    final protectedPaths = (await _documents.protectedPaths()).fold(
      (_) => <String, CopyProtection>{},
      (paths) => paths,
    );
    final now = _now();
    var remaining = copies.fold<int>(0, (sum, copy) => sum + copy.size);
    var removed = 0;
    var freed = 0;

    Future<void> remove(_Copy copy) async {
      try {
        await copy.file.delete();
      } on FileSystemException catch (e) {
        AppLogger.warning('[COPIES] could not remove ${copy.file.path}: $e');
        return;
      }
      removed++;
      freed += copy.size;
      remaining -= copy.size;
    }

    bool old(_Copy copy) => now.difference(copy.changed) >= grace;
    CopyProtection? protection(_Copy copy) => protectedPaths[copy.file.path];

    final unused = copies.where((c) => protection(c) == null && old(c)).toList()
      ..sort((a, b) => a.changed.compareTo(b.changed));
    // Unused and past the age limit: always.
    for (final copy in unused.where((c) => now.difference(c.changed) >= maxAge)) {
      await remove(copy);
    }
    if (remaining > capBytes) {
      // Over the cap: the other unused copies, oldest first, then ones that are only in Recents.
      for (final copy in unused.where((c) => c.file.existsSync())) {
        if (remaining <= capBytes) break;
        await remove(copy);
      }
      final recentOnly = copies.where((c) => protection(c) == CopyProtection.recent && old(c)).toList()
        ..sort((a, b) => a.changed.compareTo(b.changed));
      for (final copy in recentOnly) {
        if (remaining <= capBytes) break;
        await remove(copy);
      }
    }
    if (removed > 0) AppLogger.info('[COPIES] removed $removed copies, freed $freed bytes, $remaining left');
    return SharedCopyPruneResult(removed: removed, freedBytes: freed, remainingBytes: remaining);
  }
}

class _Copy {
  _Copy(this.file, this.size, this.changed);

  final File file;
  final int size;
  final DateTime changed;
}
