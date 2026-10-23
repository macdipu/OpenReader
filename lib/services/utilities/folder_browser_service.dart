import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/domain/models/document_category.dart';
import '../../core/domain/models/document_model.dart';
import '../../core/presentation/utils/logger.dart';

/// A place browsing starts from: a storage volume (Android) or one of the
/// user's folders (desktop).
class BrowseRoot {
  const BrowseRoot({required this.name, required this.path});

  final String name;
  final String path;
}

/// One folder's contents, as shown by the in-app browser: subfolders and the
/// supported documents directly inside it.
class FolderListing {
  const FolderListing({this.folders = const [], this.documents = const [], this.denied = false});

  final List<Directory> folders;
  final List<DocumentModel> documents;

  /// The OS refused to list this folder (e.g. Android/data on Android 11+).
  final bool denied;
}

/// Lists and searches folders for supported documents
/// (CR-OPENREADER-BROWSE). Replaces the former whole-storage scan: nothing is
/// walked until the user browses to a folder or asks to search one.
class FolderBrowserService {
  FolderBrowserService({List<BrowseRoot>? roots}) : _roots = roots;

  static final FolderBrowserService instance = FolderBrowserService();

  /// Explicit roots (tests); null means discover them per platform.
  final List<BrowseRoot>? _roots;

  /// Most results a "search subfolders" returns, so a broad query can't run
  /// over a whole volume collecting thousands of rows.
  static const int maxSearchResults = 500;

  static const _storageRoot = '/storage';
  static const _primaryVolume = '/storage/emulated/0';

  /// Android: primary storage first, then every other mounted volume (SD
  /// card, USB). `/storage/self` and `/storage/emulated` alias the primary
  /// volume and are skipped. Desktop: the user's home plus its Documents,
  /// Downloads and Desktop folders, where they exist.
  Future<List<BrowseRoot>> roots() async {
    if (_roots != null) return _roots;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return _desktopRoots();
    if (!Platform.isAndroid) return const [];
    final roots = <BrowseRoot>[const BrowseRoot(name: 'Internal storage', path: _primaryVolume)];
    try {
      await for (final entity in Directory(_storageRoot).list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name == 'self' || name == 'emulated') continue;
        if (entity is Directory) roots.add(BrowseRoot(name: 'SD card ($name)', path: entity.path));
      }
    } catch (e) {
      AppLogger.warning('Could not list $_storageRoot: $e');
    }
    return roots;
  }

  List<BrowseRoot> _desktopRoots() {
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    if (home == null || home.isEmpty) return const [];
    return [
      BrowseRoot(name: 'Home', path: home),
      for (final folder in const ['Documents', 'Downloads', 'Desktop'])
        if (Directory(p.join(home, folder)).existsSync()) BrowseRoot(name: folder, path: p.join(home, folder)),
    ];
  }

  Future<FolderListing> list(String path) async {
    final List<FileSystemEntity> entries;
    try {
      entries = await Directory(path).list(followLinks: false).toList();
    } catch (e) {
      AppLogger.warning('Cannot list $path: $e');
      return const FolderListing(denied: true);
    }
    final folders = <Directory>[];
    final documents = <DocumentModel>[];
    final now = DateTime.now();
    for (final raw in entries) {
      if (_isHidden(raw.path)) continue;
      final entity = await _resolve(raw);
      if (entity is Directory) {
        folders.add(entity);
      } else if (entity is File) {
        final document = await _documentFor(entity, now);
        if (document != null) documents.add(document);
      }
    }
    folders.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
    return FolderListing(folders: folders, documents: documents);
  }

  /// Supported documents under [root] whose name contains [query]
  /// (case-insensitive), depth-first, skipping hidden and unreadable
  /// folders. Stops after [maxSearchResults]; the listener cancels the
  /// subscription to stop early.
  Stream<DocumentModel> search(String root, String query) async* {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return;
    final now = DateTime.now();
    var found = 0;
    final pending = <Directory>[Directory(root)];
    // Real paths already walked, so a symlinked folder can't loop or be
    // searched twice.
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      try {
        if (!visited.add(await directory.resolveSymbolicLinks())) continue;
      } catch (_) {
        continue;
      }
      final List<FileSystemEntity> entries;
      try {
        entries = await directory.list(followLinks: false).toList();
      } catch (_) {
        continue;
      }
      for (final raw in entries) {
        if (_isHidden(raw.path)) continue;
        final entity = await _resolve(raw);
        if (entity is Directory) {
          if (!_isSystemFolder(entity.path)) pending.add(entity);
        } else if (entity is File && p.basename(entity.path).toLowerCase().contains(needle)) {
          final document = await _documentFor(entity, now);
          if (document == null) continue;
          yield document;
          if (++found >= maxSearchResults) return;
        }
      }
    }
  }

  bool _isHidden(String path) => p.basename(path).startsWith('.');

  /// A symlink as the folder or file it points to (listed under the link's
  /// own path); a broken link is dropped.
  Future<FileSystemEntity?> _resolve(FileSystemEntity entity) async {
    if (entity is! Link) return entity;
    try {
      return switch (await FileSystemEntity.type(entity.path)) {
        FileSystemEntityType.directory => Directory(entity.path),
        FileSystemEntityType.file => File(entity.path),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  /// Large app/system folders a document search shouldn't crawl: they hold
  /// no user documents and can take minutes (or, on macOS, trigger privacy
  /// prompts). Still browsable by hand.
  bool _isSystemFolder(String path) {
    final normalized = p.normalize(path);
    if (normalized.endsWith('${p.separator}Android${p.separator}data') ||
        normalized.endsWith('${p.separator}Android${p.separator}obb')) {
      return true;
    }
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    if (home == null || home.isEmpty) return false;
    return (Platform.isMacOS && p.equals(normalized, p.join(home, 'Library'))) ||
        (Platform.isWindows && p.equals(normalized, p.join(home, 'AppData')));
  }

  Future<DocumentModel?> _documentFor(File file, DateTime now) async {
    final extension = _extensionOf(file.path);
    final category = DocumentCategory.fromExtension(extension);
    if (category == DocumentCategory.unknown) return null;
    try {
      final stat = await file.stat();
      if (stat.size <= 0) return null;
      return DocumentModel(
        id: file.path,
        path: file.path,
        displayName: p.basename(file.path),
        extension: extension,
        category: category,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        lastSeenAt: now,
      );
    } catch (e) {
      AppLogger.warning('Skipping unreadable file ${file.path}: $e');
      return null;
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }
}
