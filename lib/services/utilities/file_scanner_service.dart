import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/domain/models/document_category.dart';
import '../../core/domain/models/document_model.dart';
import '../../core/presentation/utils/logger.dart';

/// Walks every accessible local storage volume for supported document files
/// (BRD 7.1): on Android the primary shared storage plus any SD card / USB
/// volume mounted under `/storage`, on desktop the user's document folders,
/// with no depth cap. Directories the OS refuses to
/// list (e.g. Android/data on Android 11+) are skipped and logged.
///
/// Named `FileScannerService` (not `DocumentScannerService`) to leave that
/// name free for a future camera-based document scanner feature.
class FileScannerService {
  FileScannerService({Iterable<String>? roots})
      : _roots = roots == null ? null : List.unmodifiable(roots);

  static final FileScannerService instance = FileScannerService();

  /// Explicit roots (tests); null means discover all volumes at scan time.
  final List<String>? _roots;

  List<String> _desktopRoots() {
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    if (home == null || home.isEmpty) return const [];
    return [for (final folder in const ['Documents', 'Downloads', 'Desktop']) p.join(home, folder)];
  }

  static const _storageRoot = '/storage';
  static const _primaryVolume = '/storage/emulated/0';

  /// Android: primary storage first, then every other mounted volume.
  /// `/storage/self` and `/storage/emulated` are aliases of the primary
  /// volume and skipped so nothing is walked twice.
  ///
  /// Windows/macOS/Linux: the user's Documents, Downloads and Desktop
  /// folders. A whole-disk walk of a desktop machine would crawl system and
  /// cache directories for minutes, so anything elsewhere is opened with the
  /// "Open file" picker instead.
  Future<List<String>> _discoverRoots() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return _desktopRoots();
    if (!Platform.isAndroid) return const [];
    final roots = <String>[_primaryVolume];
    try {
      await for (final entity in Directory(_storageRoot).list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name == 'self' || name == 'emulated') continue;
        if (entity is Directory) roots.add(entity.path);
      }
    } catch (e) {
      AppLogger.warning('Could not list $_storageRoot: $e');
    }
    return roots;
  }

  /// [onFound] fires with the running count each time a new document is
  /// added, so callers can show live scan progress (Settings > Rescan /
  /// Home's "Scan Storage") instead of a silent wait.
  Future<List<DocumentModel>> scan({void Function(int foundSoFar)? onFound}) async {
    final found = <String, DocumentModel>{};
    final now = DateTime.now();

    for (final rootPath in _roots ?? await _discoverRoots()) {
      final root = Directory(rootPath);
      if (!await root.exists()) continue;
      await _walk(root, now: now, into: found, onFound: onFound);
    }

    return found.values.toList();
  }

  Future<void> _walk(
    Directory directory, {
    required DateTime now,
    required Map<String, DocumentModel> into,
    void Function(int foundSoFar)? onFound,
  }) async {
    List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } catch (e) {
      AppLogger.warning('Skipping unreadable directory ${directory.path}: $e');
      return;
    }

    for (final entity in entries) {
      if (entity is Directory) {
        await _walk(entity, now: now, into: into, onFound: onFound);
        continue;
      }
      if (entity is! File) continue;
      if (into.containsKey(entity.path)) continue;

      final extension = _extensionOf(entity.path);
      final category = DocumentCategory.fromExtension(extension);
      if (category == DocumentCategory.unknown) continue;

      try {
        final stat = await entity.stat();
        if (stat.size <= 0) continue;
        into[entity.path] = DocumentModel(
          id: entity.path,
          path: entity.path,
          displayName: _nameOf(entity.path),
          extension: extension,
          category: category,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          lastSeenAt: now,
        );
        onFound?.call(into.length);
      } catch (e) {
        AppLogger.warning('Skipping unreadable file ${entity.path}: $e');
      }
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }

  String _nameOf(String path) => p.basename(path);
}
