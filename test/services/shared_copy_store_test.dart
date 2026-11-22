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
import 'package:openreader/services/utilities/shared_copy_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<T> success<T>(Future<Either<Failure, T>> result) async =>
    (await result).fold((failure) => throw TestFailure(failure.message), (value) => value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late Directory incoming;
  late AppDatabase database;
  late DocumentRepositoryImpl documents;
  late RecentRepositoryImpl recents;
  late FavoriteRepositoryImpl favorites;

  /// A copy of [size] bytes, indexed like a shared file.
  Future<String> copy(String name, {int size = 10}) async {
    final file = File(p.join(incoming.path, name))..writeAsBytesSync(List.filled(size, 1));
    await success(
      documents.indexDocument(
        DocumentModel(
          id: file.path,
          path: file.path,
          displayName: name,
          extension: 'pdf',
          category: DocumentCategory.pdf,
          sizeBytes: size,
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(1),
          lastSeenAt: DateTime.now(),
        ),
      ),
    );
    // Distinct change times, oldest first.
    await Future<void>.delayed(const Duration(milliseconds: 15));
    return file.path;
  }

  SharedCopyStore store({Duration later = const Duration(days: 8), int cap = 1000, Duration grace = const Duration(hours: 1)}) =>
      SharedCopyStore(
        documents: documents,
        folder: () async => incoming,
        now: () => DateTime.now().add(later),
        capBytes: cap,
        grace: grace,
      );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('openreader-copies-');
    incoming = await Directory(p.join(temporary.path, 'incoming')).create();
    database = AppDatabase(factory: databaseFactoryFfi, path: p.join(temporary.path, 'index.db'));
    documents = DocumentRepositoryImpl(appDatabase: database);
    recents = RecentRepositoryImpl(appDatabase: database);
    favorites = FavoriteRepositoryImpl(appDatabase: database);
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  bool exists(String path) => File(path).existsSync();

  test('an unused copy older than a week is removed; anything in Recents, a favorite or kept stays', () async {
    final unused = await copy('unused.pdf');
    final inRecents = await copy('recent.pdf');
    final favorite = await copy('fav.pdf');
    final kept = await copy('kept.pdf');
    final undecided = await copy('pending.pdf');
    await success(recents.markOpened(inRecents));
    await success(favorites.add(favorite));
    await success(documents.setKeepState(kept, KeepState.kept));
    await success(documents.setKeepState(undecided, KeepState.pending));

    final result = await store().prune();

    expect(result.removed, 1);
    expect(exists(unused), isFalse);
    for (final path in [inRecents, favorite, kept, undecided]) {
      expect(exists(path), isTrue, reason: path);
    }
  });

  test('a copy younger than the grace period is never removed, even unused and over the cap', () async {
    final fresh = await copy('fresh.pdf', size: 5000);
    final result = await store(later: Duration.zero, cap: 10).prune();
    expect(result.removed, 0);
    expect(exists(fresh), isTrue);
  });

  test('a young unused copy is kept while the folder is under the age limit', () async {
    final unused = await copy('unused.pdf');
    final result = await store(later: const Duration(days: 2)).prune();
    expect(result.removed, 0);
    expect(exists(unused), isTrue);
  });

  test('over the cap: unused copies go first (oldest first), then Recents-only ones, never kept ones', () async {
    final unusedOld = await copy('a_unused_old.pdf', size: 400);
    final recentOld = await copy('b_recent_old.pdf', size: 400);
    final unusedNew = await copy('c_unused_new.pdf', size: 400);
    final kept = await copy('d_kept.pdf', size: 400);
    await success(recents.markOpened(recentOld));
    await success(documents.setKeepState(kept, KeepState.kept));

    // 1600 bytes against a cap of 700. The copies are young (2 days), so only the cap removes
    // anything: the two unused ones first (800 bytes left, still over), then the Recents-only one.
    final result = await store(later: const Duration(days: 2), cap: 700).prune();

    expect(exists(unusedOld), isFalse);
    expect(exists(unusedNew), isFalse);
    expect(exists(recentOld), isFalse, reason: 'still over the cap after the unused copies, so the Recents-only one goes');
    expect(exists(kept), isTrue);
    expect(result.remainingBytes, 400);
  });

  test('over the cap with only kept copies: nothing is removed', () async {
    final kept = await copy('kept.pdf', size: 5000);
    await success(documents.setKeepState(kept, KeepState.kept));
    final result = await store(cap: 10).prune();
    expect(result.removed, 0);
    expect(exists(kept), isTrue);
  });

  test('usedBytes adds up the folder; a missing folder or another platform is a no-op', () async {
    await copy('one.pdf', size: 30);
    await copy('two.pdf', size: 70);
    expect(await store().usedBytes(), 100);

    final none = SharedCopyStore(documents: documents, folder: () async => null);
    expect(await none.usedBytes(), 0);
    expect((await none.prune()).removed, 0);
  });
}
