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
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:openreader/core/presentation/controllers/file_relocation.dart';
import 'package:openreader/core/presentation/widgets/show_dialog/file_choice_dialogs.dart';
import 'package:openreader/services/platform_integration/incoming_document_resolver.dart';
import 'package:openreader/services/platform_integration/save_copy_service.dart';
import 'package:openreader/services/utilities/app_private_paths.dart';
import 'package:openreader/services/utilities/shared_copy_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<T> success<T>(Future<Either<Failure, T>> result) async =>
    (await result).fold((failure) => throw TestFailure(failure.message), (value) => value);

class FakeSettings implements AppSettingsRepository {
  SharedCopyAction action = SharedCopyAction.ask;
  @override
  Future<SharedCopyAction> getSharedCopyAction() async => action;
  @override
  Future<void> setSharedCopyAction(SharedCopyAction value) async => action = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSaveCopy extends SaveCopyService {
  FakeSaveCopy(this.result);
  final bool result;
  final saved = <String>[];
  @override
  Future<bool> save({required String path, required String name, String? mimeType}) async {
    saved.add('$name|$mimeType');
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late Directory incoming;
  late AppDatabase database;
  late DocumentRepositoryImpl documents;
  late RecentRepositoryImpl recents;
  late FavoriteRepositoryImpl favorites;
  late FakeSettings settings;
  final errors = <String>[];

  Future<DocumentModel> index(String path, {int size = 5}) async {
    final document = DocumentModel(
      id: path,
      path: path,
      displayName: p.basename(path),
      extension: 'pdf',
      category: DocumentCategory.pdf,
      sizeBytes: size,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(1),
      lastSeenAt: DateTime.now(),
    );
    await success(documents.indexDocument(document));
    return document;
  }

  FileRelocation relocation({
    String? picked,
    MissingFileChoice? missingChoice,
    SharedCopyDecision? sharedDecision,
    FakeSaveCopy? saveCopy,
    bool androidFolder = false,
    List<String>? asked,
  }) => FileRelocation(
    documents: documents,
    settings: settings,
    privatePaths: AppPrivatePaths.fixed([incoming.path]),
    copyStore: SharedCopyStore(documents: documents, folder: () async => androidFolder ? incoming : null),
    saveCopy: saveCopy ?? FakeSaveCopy(true),
    resolver: IncomingDocumentResolver(documentRepository: documents),
    pickFile: (_) async => picked,
    askMissing: (name, {required temporaryCopy}) async {
      asked?.add('$name|temporary=$temporaryCopy');
      return missingChoice;
    },
    askSharedCopy: (name) async {
      asked?.add('ask:$name');
      return sharedDecision ?? const SharedCopyDecision(SharedCopyChoice.keep);
    },
    isSharedCopy: (path) => p.dirname(path) == incoming.path,
    showError: errors.add,
    showSuccess: (_) {},
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('openreader-reloc-');
    incoming = await Directory(p.join(temporary.path, 'incoming')).create();
    database = AppDatabase(factory: databaseFactoryFfi, path: p.join(temporary.path, 'index.db'));
    documents = DocumentRepositoryImpl(appDatabase: database);
    recents = RecentRepositoryImpl(appDatabase: database);
    favorites = FavoriteRepositoryImpl(appDatabase: database);
    settings = FakeSettings();
    errors.clear();
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  group('a file that is gone', () {
    test('Remove from Recents calls the controller and opens nothing', () async {
      final missing = await index('/gone/report.pdf');
      final removed = <String>[];
      var changed = 0;

      final result = await relocation(missingChoice: MissingFileChoice.remove).handleMissing(
        missing,
        removeFromRecents: (id) async => removed.add(id),
        onChanged: () => changed++,
      );

      expect(result, isNull);
      expect(removed, [missing.id]);
      expect(changed, 1);
    });

    test('Locate moves history, reading position and favorite to the picked file and returns it', () async {
      final missing = await index('/gone/report.pdf');
      await success(recents.markOpened(missing.id, readingPosition: {'page_number': 12}));
      await success(favorites.add(missing.id));
      final newFile = File(p.join(temporary.path, 'moved', 'report.pdf'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      var changed = 0;

      final result = await relocation(picked: newFile.path).handleMissing(
        missing,
        removeFromRecents: (_) async {},
        onChanged: () => changed++,
      );
      // handleMissing asked first; this test's askMissing returns null, so locate directly.
      expect(result, isNull);
      final located = await relocation(picked: newFile.path).locate(missing);

      expect(located?.path, newFile.path);
      expect(await success(documents.getById(missing.id)), isNull);
      expect(await success(recents.getPosition(newFile.path)), {'page_number': 12});
      expect(await success(favorites.isFavorite(newFile.path)), isTrue);
      expect(changed, 0);
    });

    test('choosing Locate in the dialog relinks and reports a change', () async {
      final missing = await index('/gone/report.pdf');
      await success(recents.markOpened(missing.id));
      final newFile = File(p.join(temporary.path, 'elsewhere.pdf'))..writeAsBytesSync([1]);
      var changed = 0;

      final result = await relocation(picked: newFile.path, missingChoice: MissingFileChoice.locate).handleMissing(
        missing,
        removeFromRecents: (_) async {},
        onChanged: () => changed++,
      );

      expect(result?.path, newFile.path);
      expect(changed, 1);
      expect((await success(recents.getRecents())).single.document.path, newFile.path);
    });

    test('cancelling the picker changes nothing', () async {
      final missing = await index('/gone/report.pdf');
      await success(recents.markOpened(missing.id));

      expect(await relocation(picked: null).locate(missing), isNull);
      expect(await success(documents.getById(missing.id)), isNotNull);
      expect(await success(recents.getRecents()), hasLength(1));
    });

    test('a file the app cannot open is refused and nothing moves', () async {
      final missing = await index('/gone/report.pdf');
      final other = File(p.join(temporary.path, 'notes.xyz'))..writeAsBytesSync([1]);

      expect(await relocation(picked: other.path).locate(missing), isNull);
      expect(errors, ["OpenReader can't open that file."]);
      expect(await success(documents.getById(missing.id)), isNotNull);
    });

    test('on Android the located file is copied into app files and kept', () async {
      final missing = await index('/gone/report.pdf');
      await success(recents.markOpened(missing.id));
      final picked = File(p.join(temporary.path, 'picked-cache', 'report.pdf'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([9, 9]);

      final located = await relocation(picked: picked.path, androidFolder: true).locate(missing);

      expect(p.dirname(located!.path), incoming.path);
      expect(p.basename(located.path), endsWith('report.pdf'));
      expect(located.displayName, 'report.pdf');
      expect(File(located.path).readAsBytesSync(), [9, 9]);
      expect(await success(documents.getKeepState(located.id)), KeepState.kept);
    });

    test('a missing copy of another app is called temporary, with no Locate', () async {
      final asked = <String>[];
      final copy = await index(p.join(incoming.path, 'abc_shared.pdf'));

      await relocation(missingChoice: null, asked: asked).handleMissing(
        copy,
        removeFromRecents: (_) async {},
        onChanged: () {},
      );

      expect(asked, ['abc_shared.pdf|temporary=true']);
    });
  });

  group('closing the reader of a copy of another app\'s file', () {
    Future<DocumentModel> pendingCopy([String name = 'abc_shared.pdf']) async {
      final path = p.join(incoming.path, name);
      File(path).writeAsBytesSync(List.filled(4, 1));
      final document = await index(path);
      await success(recents.markOpened(document.id));
      await success(documents.setKeepState(document.id, KeepState.pending));
      return document;
    }

    test('Keep marks it kept', () async {
      final copy = await pendingCopy();
      await relocation(sharedDecision: const SharedCopyDecision(SharedCopyChoice.keep))
          .onReaderClosed(copy.id, onChanged: () {});
      expect(await success(documents.getKeepState(copy.id)), KeepState.kept);
      expect(File(copy.path).existsSync(), isTrue);
    });

    test('Save a copy marks it saved when the dialog saved, and kept when it was cancelled', () async {
      final saved = FakeSaveCopy(true);
      final copy = await pendingCopy('one.pdf');
      await relocation(sharedDecision: const SharedCopyDecision(SharedCopyChoice.saveCopy), saveCopy: saved)
          .onReaderClosed(copy.id, onChanged: () {});
      expect(await success(documents.getKeepState(copy.id)), KeepState.saved);
      expect(saved.saved, ['one.pdf|application/pdf']);

      final cancelled = await pendingCopy('two.pdf');
      await relocation(
        sharedDecision: const SharedCopyDecision(SharedCopyChoice.saveCopy),
        saveCopy: FakeSaveCopy(false),
      ).onReaderClosed(cancelled.id, onChanged: () {});
      expect(await success(documents.getKeepState(cancelled.id)), KeepState.kept);
    });

    test('Remove deletes the file, the row and the Recents entry, and tells the lists', () async {
      final copy = await pendingCopy();
      var changed = 0;
      await relocation(sharedDecision: const SharedCopyDecision(SharedCopyChoice.remove))
          .onReaderClosed(copy.id, onChanged: () => changed++);
      expect(File(copy.path).existsSync(), isFalse);
      expect(await success(documents.getById(copy.id)), isNull);
      expect(await success(recents.getRecents()), isEmpty);
      expect(changed, 1);
    });

    test('"Do this every time" stores the setting, except for Save a copy', () async {
      final a = await pendingCopy('a.pdf');
      await relocation(sharedDecision: const SharedCopyDecision(SharedCopyChoice.remove, remember: true))
          .onReaderClosed(a.id, onChanged: () {});
      expect(settings.action, SharedCopyAction.remove);

      settings.action = SharedCopyAction.ask;
      final b = await pendingCopy('b.pdf');
      await relocation(sharedDecision: const SharedCopyDecision(SharedCopyChoice.saveCopy, remember: true))
          .onReaderClosed(b.id, onChanged: () {});
      expect(settings.action, SharedCopyAction.ask);
    });

    test('the setting answers without asking', () async {
      final asked = <String>[];
      settings.action = SharedCopyAction.keep;
      final kept = await pendingCopy('k.pdf');
      await relocation(asked: asked).onReaderClosed(kept.id, onChanged: () {});
      expect(await success(documents.getKeepState(kept.id)), KeepState.kept);

      settings.action = SharedCopyAction.remove;
      final removed = await pendingCopy('r.pdf');
      await relocation(asked: asked).onReaderClosed(removed.id, onChanged: () {});
      expect(File(removed.path).existsSync(), isFalse);
      expect(asked, isEmpty);
    });

    test('an already decided copy, an ordinary file and no document are left alone', () async {
      final asked = <String>[];
      final decided = await pendingCopy('d.pdf');
      await success(documents.setKeepState(decided.id, KeepState.kept));
      final ordinary = await index('/home/user/book.pdf');

      final r = relocation(asked: asked);
      await r.onReaderClosed(decided.id, onChanged: () {});
      await r.onReaderClosed(ordinary.id, onChanged: () {});
      await r.onReaderClosed(null, onChanged: () {});

      expect(asked, isEmpty);
      expect(await success(documents.getKeepState(decided.id)), KeepState.kept);
    });
  });
}
