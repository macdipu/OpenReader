import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local relational store for the document index, recent history, and
/// favorites (BRD 16 - Local Data Model). Opened lazily and cached; there is
/// no server, so the schema lives entirely on-device.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
      : _factory = factory,
        _path = path;

  static final AppDatabase instance = AppDatabase();
  final DatabaseFactory? _factory;
  final String? _path;

  static const _fileName = 'openreader.db';
  static const _legacyFileName = 'opendocs.db';
  /// 2: legacy `.doc`/`.xls` are no longer indexed (CR-OPENREADER-UX UX-06),
  /// so rows an older install indexed are pruned on upgrade - see [_onUpgrade].
  static const _version = 2;

  Database? _database;

  Future<Database> get database async {
    return _database ??= await _open();
  }

  /// Renamed from `opendocs.db` (ODF-P5 app rename). Existing installs keep
  /// their recents/favorites by having the old file renamed in place on first
  /// open after upgrade, rather than starting from an empty index.
  Future<void> _migrateLegacyFileName(String directory, String path) async {
    if (await File(path).exists()) return;
    final legacy = File(p.join(directory, _legacyFileName));
    if (await legacy.exists()) {
      await legacy.rename(path);
    }
  }

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final directory = await factory.getDatabasesPath();
    final path = _path ?? p.join(directory, _fileName);
    if (_path == null) {
      await _migrateLegacyFileName(directory, path);
    }
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            path TEXT NOT NULL UNIQUE,
            display_name TEXT NOT NULL,
            extension TEXT NOT NULL,
            category TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            last_seen_at INTEGER NOT NULL
          )
        ''');
          await db.execute(
              'CREATE INDEX idx_documents_category ON documents(category)');
          await db.execute(
              'CREATE INDEX idx_documents_display_name ON documents(display_name)');

          await db.execute('''
          CREATE TABLE recent_documents (
            document_id TEXT PRIMARY KEY REFERENCES documents(id) ON DELETE CASCADE,
            last_opened_at INTEGER NOT NULL,
            reading_position TEXT NOT NULL DEFAULT '{}'
          )
        ''');

          await db.execute('''
          CREATE TABLE favorite_documents (
            document_id TEXT PRIMARY KEY REFERENCES documents(id) ON DELETE CASCADE,
            favorited_at INTEGER NOT NULL
          )
        ''');
        },
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Version 1 indexed `.doc`/`.xls` as Word/Excel, which the readers can't
  /// open. A rescan prunes them too; this does it at once, so an upgraded
  /// install doesn't list them until the user happens to rescan. Their
  /// recents/favorites go with them via `ON DELETE CASCADE`.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.delete('documents', where: "lower(extension) IN ('doc', 'xls')");
    }
  }

  /// Test/debug hook; not wired to any UI action in Phase 1.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
