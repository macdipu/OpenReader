import 'dart:io';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';

/// Deletes the history entries older than the saved retention (ST-12). Does nothing for "forever"
/// (null) and for "off" (0), which stops recording instead. Never throws. Returns whether it
/// deleted anything it was asked to.
Future<bool> enforceHistoryRetention({
  AppSettingsRepository? settings,
  RecentRepository? recents,
  DateTime? now,
}) async {
  try {
    final days = await (settings ?? AppSettingsRepositoryImpl()).getHistoryRetentionDays();
    if (days == null || days <= 0) return false;
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final result = await (recents ?? RecentRepositoryImpl()).removeOlderThan(cutoff);
    return result.isRight();
  } catch (_) {
    return false;
  }
}

/// Deletes the oldest files under [directory] (by modified time) until the rest fit in [capBytes]
/// (ST-11). Files that cannot be deleted are skipped. Never throws. Returns the bytes removed.
Future<int> trimDirectoryToCap(Directory directory, int capBytes) async {
  var removed = 0;
  try {
    if (!await directory.exists()) return 0;
    final files = <({File file, int size, DateTime modified})>[];
    var total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        files.add((file: entity, size: stat.size, modified: stat.modified));
        total += stat.size;
      } catch (_) {}
    }
    if (total <= capBytes) return 0;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    for (final f in files) {
      if (total <= capBytes) break;
      try {
        await f.file.delete();
        total -= f.size;
        removed += f.size;
      } catch (_) {}
    }
  } catch (_) {}
  return removed;
}

/// Subdirectories of the temp directory that hold only render cache (safe to trim). The incoming
/// documents copy (`incoming`) and the desktop updater download (`openreader_update`) live next
/// to them and are never trimmed.
/// Entries of the temp directory that are not cache: documents opened from other apps and the
/// desktop update download. Clear cache and the cache size leave them out.
const protectedTempEntries = <String>['incoming', 'openreader_update'];

const renderCacheDirectories = <String>['document_thumbnails'];

/// [trimDirectoryToCap] over each known render cache under [tempDirectory], sharing one [capBytes]
/// budget per directory. Anything else in [tempDirectory] is left alone. Returns the bytes removed.
Future<int> trimRenderCachesToCap(Directory tempDirectory, int capBytes) async {
  var removed = 0;
  for (final name in renderCacheDirectories) {
    removed += await trimDirectoryToCap(Directory('${tempDirectory.path}${Platform.pathSeparator}$name'), capBytes);
  }
  return removed;
}
