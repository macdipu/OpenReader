import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/data/local/app_database.dart';
import 'package:openreader/core/data/repositories/document_repository_impl.dart';
import 'package:openreader/core/data/repositories/favorite_repository_impl.dart';
import 'package:openreader/core/data/repositories/recent_repository_impl.dart';
import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/models/keep_state.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DocumentModel document(String path, {int size = 10}) => DocumentModel(
  id: path,
  path: path,
  displayName: p.basename(path),
  extension: 'pdf',
  category: DocumentCategory.pdf,
  sizeBytes: size,
  modifiedAt: DateTime.fromMillisecondsSinceEpoch(1),
  lastSeenAt: DateTime.fromMillisecondsSinceEpoch(100),
);

Future<T> success<T>(Future<Either<Failure, T>> result) async =>
    (await result).fold((failure) => throw TestFailure(failure.message), (value) => value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late AppDatabase database;
  late DocumentRepositoryImpl documents;
  late FavoriteRepositoryImpl favorites;
  late RecentRepositoryImpl recents;
  final old = document('/old/report.pdf');
  final moved = document('/new/report.pdf');

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('openreader-relink-');
    database = AppDatabase(factory: databaseFactoryFfi, path: p.join(temporary.path, 'index.db'));
    documents = DocumentRepositoryImpl(appDatabase: database);
    favorites = FavoriteRepositoryImpl(appDatabase: database);
    recents = RecentRepositoryImpl(appDatabase: database);
    await success(documents.indexDocument(old));
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  test('keep state: none by default, set, cleared, and unchanged by indexing the document again', () async {
    expect(await success(documents.getKeepState(old.id)), isNull);
    await success(documents.setKeepState(old.id, KeepState.kept));
    expect(await success(documents.getKeepState(old.id)), KeepState.kept);
    await success(documents.indexDocument(old));
    expect(await success(documents.getKeepState(old.id)), KeepState.kept);
    await success(documents.setKeepState(old.id, null));
    expect(await success(documents.getKeepState(old.id)), isNull);
    expect(await success(documents.getKeepState('/not/indexed.pdf')), isNull);
  });

  test('referencedPaths: only documents with a recent entry or a favorite', () async {
    final unreferenced = document('/cache/incoming/x_other.pdf');
    await success(documents.indexDocument(unreferenced));
    expect(await success(documents.referencedPaths()), isEmpty);
    await success(recents.markOpened(old.id));
    final favored = document('/cache/incoming/y_fav.pdf');
    await success(documents.indexDocument(favored));
    await success(favorites.add(favored.id));
    expect(await success(documents.referencedPaths()), {old.path, favored.path});
  });

  test('relink moves the recent entry with its reading position, and the favorite', () async {
    await success(recents.markOpened(old.id, readingPosition: {'page_number': 7}));
    await success(favorites.add(old.id));

    await success(documents.relink(old.id, moved));

    expect(await success(documents.getById(old.id)), isNull);
    expect((await success(documents.getById(moved.id)))?.path, moved.path);
    final recent = (await success(recents.getRecents())).single;
    expect(recent.document.id, moved.id);
    expect(await success(recents.getPosition(moved.id)), {'page_number': 7});
    expect(await success(favorites.isFavorite(moved.id)), isTrue);
    expect(await success(favorites.isFavorite(old.id)), isFalse);
  });

  test('relink stores the keep state on the replacement', () async {
    await success(recents.markOpened(old.id));
    await success(documents.relink(old.id, moved, keepState: KeepState.saved));
    expect(await success(documents.getKeepState(moved.id)), KeepState.saved);
  });

  test('relink onto a document that already has history keeps the newer entry and a favorite on either', () async {
    await success(documents.indexDocument(moved));
    await success(recents.markOpened(moved.id, readingPosition: {'page_number': 2}));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await success(recents.markOpened(old.id, readingPosition: {'page_number': 9}));
    await success(favorites.add(old.id));

    await success(documents.relink(old.id, moved));

    expect(await success(recents.getRecents()), hasLength(1));
    expect(await success(recents.getPosition(moved.id)), {'page_number': 9});
    expect(await success(favorites.isFavorite(moved.id)), isTrue);
    expect(await success(documents.getById(old.id)), isNull);
  });

  test('relink never lets an empty position replace a real one', () async {
    await success(documents.indexDocument(moved));
    await success(recents.markOpened(old.id, readingPosition: {'page_number': 5}));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await success(recents.markOpened(moved.id));

    await success(documents.relink(old.id, moved));

    expect(await success(recents.getPosition(moved.id)), {'page_number': 5});
  });

  test('relink to the same id only refreshes the row', () async {
    await success(recents.markOpened(old.id));
    await success(documents.relink(old.id, document(old.path, size: 99)));
    expect((await success(documents.getById(old.id)))?.sizeBytes, 99);
    expect(await success(recents.getRecents()), hasLength(1));
  });

  test('upgrading a real version 3 database adds keep_state and keeps its rows', () async {
    final path = p.join(temporary.path, 'v3.db');
    final v3 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE documents (id TEXT PRIMARY KEY, path TEXT NOT NULL UNIQUE, '
            'display_name TEXT NOT NULL, extension TEXT NOT NULL, category TEXT NOT NULL, '
            'size_bytes INTEGER NOT NULL, modified_at INTEGER NOT NULL, last_seen_at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE recent_documents (document_id TEXT PRIMARY KEY REFERENCES documents(id) '
            "ON DELETE CASCADE, last_opened_at INTEGER NOT NULL, reading_position TEXT NOT NULL DEFAULT '{}')",
          );
          await db.execute(
            'CREATE TABLE favorite_documents (document_id TEXT PRIMARY KEY REFERENCES documents(id) '
            'ON DELETE CASCADE, favorited_at INTEGER NOT NULL)',
          );
        },
      ),
    );
    await v3.insert('documents', old.toMap());
    await v3.insert('recent_documents', {
      'document_id': old.id,
      'last_opened_at': 5,
      'reading_position': '{"page_number":3}',
    });
    await v3.close();

    final upgraded = AppDatabase(factory: databaseFactoryFfi, path: path);
    final repo = DocumentRepositoryImpl(appDatabase: upgraded);
    final recent = RecentRepositoryImpl(appDatabase: upgraded);
    addTearDown(upgraded.close);

    expect(await success(repo.getKeepState(old.id)), isNull);
    expect((await success(repo.getById(old.id)))?.path, old.path);
    expect(await success(recent.getPosition(old.id)), {'page_number': 3});
    await success(repo.setKeepState(old.id, KeepState.pending));
    expect(await success(repo.getKeepState(old.id)), KeepState.pending);
  });
}
