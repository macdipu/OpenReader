import 'dart:io';

import 'package:openreader/core/data/local/app_database.dart';
import 'package:openreader/core/data/repositories/document_repository_impl.dart';
import 'package:openreader/core/data/repositories/favorite_repository_impl.dart';
import 'package:openreader/core/data/repositories/recent_repository_impl.dart';
import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/services/utilities/file_scanner_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FixtureScanner implements FileScannerService {
  List<DocumentModel> documents = [];
  bool fail = false;
  @override
  Future<List<DocumentModel>> scan() async {
    if (fail) throw const FileSystemException('Scan failed');
    return documents;
  }
}

DocumentModel document(String name,
        {int size = 10, int modified = 1, String? path}) =>
    DocumentModel(
      id: path ?? '/fixtures/$name',
      path: path ?? '/fixtures/$name',
      displayName: name,
      extension: p.extension(name).substring(1),
      category: DocumentCategory.fromExtension(p.extension(name).substring(1)),
      sizeBytes: size,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(modified),
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(100),
    );

Future<T> success<T>(Future<Either<Failure, T>> result) async => (await result)
    .fold((failure) => throw TestFailure(failure.message), (value) => value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late AppDatabase database;
  late FixtureScanner scanner;
  late DocumentRepositoryImpl documents;
  late FavoriteRepositoryImpl favorites;
  late RecentRepositoryImpl recents;
  final a = document('Alpha.pdf', size: 30, modified: 200);
  final b = document('beta.txt', modified: 300);
  final c = document('charlie.pdf', size: 20, modified: 100);

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('openreader-db-');
    database = AppDatabase(
        factory: databaseFactoryFfi, path: p.join(temporary.path, 'index.db'));
    scanner = FixtureScanner()..documents = [b, c, a];
    documents = DocumentRepositoryImpl(appDatabase: database, scanner: scanner);
    favorites = FavoriteRepositoryImpl(appDatabase: database);
    recents = RecentRepositoryImpl(appDatabase: database);
    await success(documents.rescan());
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  test('lookup, category counts, filtering, trimmed case-insensitive search',
      () async {
    expect(await success(documents.getById(a.id)), a);
    expect(await success(documents.getById('missing')), isNull);
    expect(await success(documents.countByCategory(DocumentCategory.pdf)), 2);
    expect(await success(documents.countByCategory(DocumentCategory.csv)), 0);
    expect(
        await success(documents.getDocuments(category: DocumentCategory.pdf)),
        [a, c]);
    expect(await success(documents.getDocuments(query: '  ALpHa  ')), [a]);
    expect(await success(documents.getDocuments(query: '   ')), [a, b, c]);
    expect(
        await success(documents.getDocuments(
            category: DocumentCategory.text, query: 'alpha')),
        isEmpty);
    expect(
        await success(documents.getDocuments(query: "' OR 1=1 --")), isEmpty);
  });

  final orders = {
    DocumentSortMode.nameAsc: [a, b, c],
    DocumentSortMode.nameDesc: [c, b, a],
    DocumentSortMode.newestFirst: [b, a, c],
    DocumentSortMode.oldestFirst: [c, a, b],
    DocumentSortMode.largestFirst: [a, c, b],
    DocumentSortMode.smallestFirst: [b, c, a],
  };
  for (final order in orders.entries) {
    test('sorts by ${order.key.name}', () async {
      expect(
          await success(documents.getDocuments(sort: order.key)), order.value);
    });
  }

  test('repeated scan preserves favorites, recents and reading position',
      () async {
    await success(favorites.add(a.id));
    await success(
        recents.markOpened(a.id, readingPosition: {'page': 7, 'zoom': 1.5}));
    final before = (await success(recents.getRecents())).single;
    final updated = document('Alpha.pdf', size: 99, modified: 900);
    scanner.documents = [updated, b, c];
    await success(documents.rescan());
    expect(await success(favorites.isFavorite(a.id)), isTrue);
    expect(await success(favorites.getFavorites()), [updated]);
    final recent = (await success(recents.getRecents())).single;
    expect(recent.document, updated);
    expect(recent.readingPosition, {'page': 7, 'zoom': 1.5});
    expect(recent.lastOpenedAt, before.lastOpenedAt);
    await database.close();
    expect(await success(favorites.isFavorite(a.id)), isTrue);
  });

  test('prunes removed index records and child rows without touching files',
      () async {
    final file =
        await File(p.join(temporary.path, 'keep.pdf')).writeAsString('keep me');
    final diskDocument = document('keep.pdf', path: file.path);
    scanner.documents = [diskDocument, a];
    await success(documents.rescan());
    await success(favorites.add(diskDocument.id));
    await success(recents.markOpened(diskDocument.id));
    scanner.documents = [a];
    await success(documents.rescan());
    expect(await success(documents.getById(diskDocument.id)), isNull);
    expect(await success(favorites.getFavorites()), isEmpty);
    expect(await success(recents.getRecents()), isEmpty);
    expect(await file.readAsString(), 'keep me');
    scanner.documents = [];
    await success(documents.rescan());
    expect(await success(documents.getDocuments()), isEmpty);
  });

  test('favorites add, remove, toggle, ordering and idempotence', () async {
    await success(favorites.add(a.id));
    await success(favorites.add(a.id));
    await success(favorites.add(b.id));
    final db = await database.database;
    await db.update('favorite_documents', {'favorited_at': 1},
        where: 'document_id = ?', whereArgs: [a.id]);
    await db.update('favorite_documents', {'favorited_at': 2},
        where: 'document_id = ?', whereArgs: [b.id]);
    expect(await success(favorites.getFavorites()), [b, a]);
    await success(favorites.remove(b.id));
    await success(favorites.toggle(a.id));
    expect(await success(favorites.isFavorite(a.id)), isFalse);
    await success(favorites.toggle(a.id));
    expect(await success(favorites.isFavorite(a.id)), isTrue);
    expect(await success(documents.getDocuments()), hasLength(3));
  });

  test(
      'recents round-trip positions, update, order, remove and clear independently',
      () async {
    await success(favorites.add(a.id));
    await success(recents.markOpened(a.id, readingPosition: {'page': 1}));
    await success(recents.markOpened(a.id, readingPosition: {
      'page': 2,
      'offset': [1, 2]
    }));
    await success(recents.markOpened(b.id));
    final db = await database.database;
    await db.update('recent_documents', {'last_opened_at': 1},
        where: 'document_id = ?', whereArgs: [a.id]);
    await db.update('recent_documents', {'last_opened_at': 2},
        where: 'document_id = ?', whereArgs: [b.id]);
    final history = await success(recents.getRecents());
    expect(history.map((r) => r.document.id), [b.id, a.id]);
    expect(history.last.readingPosition, {
      'page': 2,
      'offset': [1, 2]
    });
    await success(recents.remove(b.id));
    expect(await success(recents.getRecents()), hasLength(1));
    await success(recents.clearAll());
    expect(await success(recents.getRecents()), isEmpty);
    expect(await success(favorites.isFavorite(a.id)), isTrue);
    expect(await success(documents.getDocuments()), hasLength(3));
  });

  test('scan failure preserves the previous index and metadata', () async {
    await success(favorites.add(a.id));
    scanner.fail = true;
    expect((await documents.rescan()).isLeft(), isTrue);
    expect(await success(documents.getDocuments()), [a, b, c]);
    expect(await success(favorites.isFavorite(a.id)), isTrue);
  });

  test('transaction failure rolls back earlier writes and metadata changes',
      () async {
    await success(favorites.add(a.id));
    scanner.documents = [
      document('Alpha.pdf', size: 99),
      document('bad.txt', size: 42)
    ];
    final db = await database.database;
    await db.execute(
        "CREATE TRIGGER reject_bad BEFORE INSERT ON documents WHEN NEW.display_name = 'bad.txt' BEGIN SELECT RAISE(ABORT, 'fixture rejection'); END");
    expect((await documents.rescan()).isLeft(), isTrue);
    expect(await success(documents.getDocuments()), [a, b, c]);
    expect(await success(favorites.isFavorite(a.id)), isTrue);
  });

  test(
      'database failures use Failure/Either and foreign keys reject missing documents',
      () async {
    expect((await favorites.add('missing')).isLeft(), isTrue);
    expect((await recents.markOpened('missing')).isLeft(), isTrue);
    await (await database.database).close();
    expect((await documents.getDocuments()).isLeft(), isTrue);
    expect((await favorites.getFavorites()).isLeft(), isTrue);
    expect((await recents.getRecents()).isLeft(), isTrue);
  });
}
