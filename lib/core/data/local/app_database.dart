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

  static const _fileName = 'opendocs.db';
  static const _version = 1;

  Database? _database;

  Future<Database> get database async {
    return _database ??= await _open();
  }

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? p.join(await factory.getDatabasesPath(), _fileName);
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
      ),
    );
  }

  /// Test/debug hook; not wired to any UI action in Phase 1.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
