import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/document_model.dart';
import '../../domain/models/recent_document_model.dart';
import '../../domain/repositories/recent_repository.dart';
import '../../domain/usecase/usecase.dart';
import '../../presentation/utils/task_runner.dart';
import '../local/app_database.dart';

class RecentRepositoryImpl implements RecentRepository {
  final AppDatabase _appDatabase;

  RecentRepositoryImpl({AppDatabase? appDatabase}) : _appDatabase = appDatabase ?? AppDatabase.instance;

  @override
  ResultFuture<List<RecentDocumentModel>> getRecents() {
    return runTask(() async {
      final db = await _appDatabase.database;
      final rows = await db.rawQuery('''
        SELECT d.*, r.last_opened_at, r.reading_position
        FROM recent_documents r
        INNER JOIN documents d ON d.id = r.document_id
        ORDER BY r.last_opened_at DESC
      ''');

      return rows.map((row) {
        final document = DocumentModel.fromMap(row);
        return RecentDocumentModel(
          document: document,
          lastOpenedAt: DateTime.fromMillisecondsSinceEpoch(row['last_opened_at'] as int),
          readingPosition: Map<String, Object?>.from(
            jsonDecode(row['reading_position'] as String) as Map,
          ),
        );
      }).toList();
    });
  }

  @override
  ResultFuture<void> markOpened(String documentId, {Map<String, Object?> readingPosition = const {}}) {
    return runTask(() async {
      final db = await _appDatabase.database;
      await db.insert(
        'recent_documents',
        {
          'document_id': documentId,
          'last_opened_at': DateTime.now().millisecondsSinceEpoch,
          'reading_position': jsonEncode(readingPosition),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  ResultFuture<void> remove(String documentId) {
    return runTask(() async {
      final db = await _appDatabase.database;
      await db.delete('recent_documents', where: 'document_id = ?', whereArgs: [documentId]);
    });
  }

  @override
  ResultFuture<void> clearAll() {
    return runTask(() async {
      final db = await _appDatabase.database;
      await db.delete('recent_documents');
    });
  }
}
