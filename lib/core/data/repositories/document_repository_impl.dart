import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/document_category.dart';
import '../../domain/models/document_model.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/usecase/usecase.dart';
import '../../presentation/utils/task_runner.dart';
import '../local/app_database.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final AppDatabase _appDatabase;

  DocumentRepositoryImpl({AppDatabase? appDatabase}) : _appDatabase = appDatabase ?? AppDatabase.instance;

  @override
  ResultFuture<DocumentModel> indexDocument(DocumentModel document) {
    return runTask(() async {
      final db = await _appDatabase.database;
      // Insert-or-update, never REPLACE: SQLite's REPLACE deletes the old row
      // first, which cascades into the document's favorite and reading
      // position - and browsing re-indexes a document on every open.
      await db.transaction((txn) async {
        await txn.insert('documents', document.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.update('documents', document.toMap(), where: 'id = ?', whereArgs: [document.id]);
      });
      return document;
    });
  }

  @override
  ResultFuture<List<DocumentModel>> getDocuments({
    DocumentCategory? category,
    String? query,
    DocumentSortMode sort = DocumentSortMode.nameAsc,
  }) {
    return runTask(() async {
      final db = await _appDatabase.database;
      final where = <String>[];
      final whereArgs = <Object?>[];

      if (category != null) {
        where.add('category = ?');
        whereArgs.add(category.name);
      }
      final trimmedQuery = query?.trim();
      if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
        where.add('display_name LIKE ?');
        whereArgs.add('%$trimmedQuery%');
      }

      final rows = await db.query(
        'documents',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: _orderByFor(sort),
      );

      return rows.map(DocumentModel.fromMap).toList();
    });
  }

  @override
  ResultFuture<DocumentModel?> getById(String id) {
    return runTask(() async {
      final db = await _appDatabase.database;
      final rows = await db.query('documents',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return null;
      return DocumentModel.fromMap(rows.first);
    });
  }

  @override
  ResultFuture<int> countByCategory(DocumentCategory category) {
    return runTask(() async {
      final db = await _appDatabase.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM documents WHERE category = ?',
        [category.name],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    });
  }

  @override
  ResultFuture<void> deleteDocument(DocumentModel document) {
    return runTask(() async {
      final file = File(document.path);
      if (await file.exists()) await file.delete();
      final db = await _appDatabase.database;
      await db.delete('documents', where: 'id = ?', whereArgs: [document.id]);
    });
  }

  String _orderByFor(DocumentSortMode sort) {
    switch (sort) {
      case DocumentSortMode.nameAsc:
        return 'display_name COLLATE NOCASE ASC';
      case DocumentSortMode.nameDesc:
        return 'display_name COLLATE NOCASE DESC';
      case DocumentSortMode.newestFirst:
        return 'modified_at DESC';
      case DocumentSortMode.oldestFirst:
        return 'modified_at ASC';
      case DocumentSortMode.largestFirst:
        return 'size_bytes DESC';
      case DocumentSortMode.smallestFirst:
        return 'size_bytes ASC';
    }
  }
}
