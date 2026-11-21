import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/data/local/app_database.dart';
import 'package:openreader/core/data/repositories/app_settings_repository_impl.dart';
import 'package:openreader/core/data/repositories/recent_repository_impl.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/data/repositories/document_repository_impl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// History retention "Off" (CR-SETTINGS-UX ST-12): nothing is recorded, including positions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late AppDatabase database;
  late RecentRepositoryImpl recents;
  final doc = DocumentModel(
    id: '/fixtures/a.pdf',
    path: '/fixtures/a.pdf',
    displayName: 'a.pdf',
    extension: 'pdf',
    category: DocumentCategory.pdf,
    sizeBytes: 1,
    modifiedAt: DateTime.fromMillisecondsSinceEpoch(1),
    lastSeenAt: DateTime.fromMillisecondsSinceEpoch(1),
  );

  Future<void> retention(int? days) async {
    SharedPreferences.setMockInitialValues({if (days != null) 'app_settings:history_retention_days': days});
    recents = RecentRepositoryImpl(appDatabase: database, settings: AppSettingsRepositoryImpl());
  }

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('openreader-history-off-');
    database = AppDatabase(factory: databaseFactoryFfi, path: p.join(temporary.path, 'index.db'));
    await DocumentRepositoryImpl(appDatabase: database).indexDocument(doc);
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  Future<int> count() async => (await recents.getRecents()).fold((_) => -1, (r) => r.length);

  test('markOpened and touch record nothing when history is Off', () async {
    await retention(0);
    await recents.markOpened(doc.id, readingPosition: {'page_number': 4});
    await recents.touch(doc.id);
    expect(await count(), 0);
    expect((await recents.getPosition(doc.id)).getOrElse(() => {'x': 1}), isEmpty);
  });

  test('markOpened and touch record when history is on', () async {
    await retention(30);
    await recents.markOpened(doc.id, readingPosition: {'page_number': 4});
    expect(await count(), 1);
    expect((await recents.getPosition(doc.id)).getOrElse(() => {}), {'page_number': 4});
    await recents.touch(doc.id);
    expect(await count(), 1);
  });

  test('Off leaves existing rows alone; removeOlderThan deletes only older ones', () async {
    await retention(null);
    await recents.markOpened(doc.id, readingPosition: {'page_number': 2});
    await retention(0);
    await recents.markOpened(doc.id, readingPosition: {'page_number': 9});
    expect((await recents.getPosition(doc.id)).getOrElse(() => {}), {'page_number': 2}, reason: 'not overwritten');
    expect(await count(), 1);

    await recents.removeOlderThan(DateTime.fromMillisecondsSinceEpoch(1));
    expect(await count(), 1, reason: 'cutoff before the row');
    await recents.removeOlderThan(DateTime.now().add(const Duration(days: 1)));
    expect(await count(), 0);
  });
}
