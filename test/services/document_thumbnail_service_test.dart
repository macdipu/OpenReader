import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/services/utilities/document_thumbnail_service.dart';
import 'package:openreader/services/utilities/path_service.dart';

class _FakePathService implements PathService {
  _FakePathService(this.temp);

  final Directory temp;

  @override
  ResultFuture<Directory> getTempDirectory() async => Right(temp);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DocumentModel _document(String path, {DateTime? modifiedAt}) {
  final extension = path.split('.').last;
  return DocumentModel(
    id: path,
    path: path,
    displayName: path.split('/').last,
    extension: extension,
    category: DocumentCategory.fromExtension(extension),
    sizeBytes: 1,
    modifiedAt: modifiedAt ?? DateTime(2026),
    lastSeenAt: DateTime(2026),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('thumbnail_service_test'));
  tearDown(() => temp.delete(recursive: true));

  test('renders once, then serves the disk cache until the file changes', () async {
    final rendered = <String>[];
    DocumentThumbnailService service() => DocumentThumbnailService.withDependencies(
          pathService: _FakePathService(temp),
          render: (path, {required width}) async {
            rendered.add('$path@$width');
            return Uint8List.fromList([1, 2, 3]);
          },
        );

    final first = await service().getThumbnail(_document('/docs/a.docx'));
    expect(first, isNotNull);
    expect(first!.readAsBytesSync(), [1, 2, 3]);
    // A fresh service (as after an app restart) finds it on disk.
    expect((await service().getThumbnail(_document('/docs/a.docx')))!.path, first.path);
    expect(rendered, ['/docs/a.docx@160']);

    final edited = await service().getThumbnail(_document('/docs/a.docx', modifiedAt: DateTime(2027)));
    expect(edited!.path, isNot(first.path));
    expect(rendered, hasLength(2));
  });

  test('one render for concurrent requests of the same document', () async {
    var renders = 0;
    final service = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      render: (path, {required width}) async {
        renders++;
        return Uint8List.fromList([1]);
      },
    );
    final document = _document('/docs/deck.pptx');
    await Future.wait([service.getThumbnail(document), service.getThumbnail(document)]);
    expect(renders, 1);
  });

  test('null when the kit has no preview or rendering fails', () async {
    final none = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      render: (path, {required width}) async => null,
    );
    expect(await none.getThumbnail(_document('/docs/broken.xlsx')), isNull);

    final failing = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      render: (path, {required width}) async => throw StateError('boom'),
    );
    expect(await failing.getThumbnail(_document('/docs/notes.txt')), isNull);
  });

  test('previews a real non-PDF file through open_reader_kit', () async {
    final path = '${temp.path}/notes.txt';
    File(path).writeAsStringSync('Shopping list\nMilk\nBread\n');
    final service = DocumentThumbnailService.withDependencies(pathService: _FakePathService(temp));

    final file = await service.getThumbnail(_document(path));
    expect(file, isNotNull);
    expect(file!.readAsBytesSync().sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
