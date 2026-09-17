import 'package:sqflite/sqflite.dart';

import '../../domain/models/document_model.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/usecase/usecase.dart';
import '../../presentation/utils/task_runner.dart';
import '../local/app_database.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  final AppDatabase _appDatabase;

  FavoriteRepositoryImpl({AppDatabase? appDatabase}) : _appDatabase = appDatabase ?? AppDatabase.instance;

  @override
  ResultFuture<List<DocumentModel>> getFavorites() {
    return runTask(() async {
      final db = await _appDatabase.database;
      final rows = await db.rawQuery('''
        SELECT d.*
        FROM favorite_documents f
        INNER JOIN documents d ON d.id = f.document_id
        ORDER BY f.favorited_at DESC
      ''');
      return rows.map(DocumentModel.fromMap).toList();
    });
  }

  @override
  ResultFuture<bool> isFavorite(String documentId) {
    return runTask(() async {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'favorite_documents',
        where: 'document_id = ?',
        whereArgs: [documentId],
        limit: 1,
      );
      return rows.isNotEmpty;
    });
  }

  @override
  ResultFuture<void> add(String documentId) {
    return runTask(() async {
      final db = await _appDatabase.database;
      await db.insert(
        'favorite_documents',
        {'document_id': documentId, 'favorited_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  ResultFuture<void> remove(String documentId) {
    return runTask(() async {
      final db = await _appDatabase.database;
      await db.delete('favorite_documents', where: 'document_id = ?', whereArgs: [documentId]);
    });
  }

  @override
  ResultFuture<void> toggle(String documentId) {
    return runTask(() async {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'favorite_documents',
        where: 'document_id = ?',
        whereArgs: [documentId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await db.insert('favorite_documents', {
          'document_id': documentId,
          'favorited_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await db.delete('favorite_documents', where: 'document_id = ?', whereArgs: [documentId]);
      }
    });
  }
}
