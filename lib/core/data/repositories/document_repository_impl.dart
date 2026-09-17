import 'package:sqflite/sqflite.dart';

import '../../domain/models/document_category.dart';
import '../../domain/models/document_model.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/usecase/usecase.dart';
import '../../presentation/utils/task_runner.dart';
import '../local/app_database.dart';
import '../../../services/utilities/document_scanner_service.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final AppDatabase _appDatabase;
  final DocumentScannerService _scanner;

  DocumentRepositoryImpl({
    AppDatabase? appDatabase,
    DocumentScannerService? scanner,
  })  : _appDatabase = appDatabase ?? AppDatabase.instance,
        _scanner = scanner ?? DocumentScannerService.instance;

  @override
  ResultFuture<List<DocumentModel>> rescan() {
    return runTask(() async {
      final found = await _scanner.scan();
      final db = await _appDatabase.database;

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final document in found) {
          batch.insert(
            'documents',
            document.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);

        if (found.isNotEmpty) {
          final placeholders = List.filled(found.length, '?').join(',');
          await txn.delete(
            'documents',
            where: 'path NOT IN ($placeholders)',
            whereArgs: found.map((d) => d.path).toList(),
          );
        } else {
          await txn.delete('documents');
        }
      });

      return found;
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
      final rows = await db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
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
