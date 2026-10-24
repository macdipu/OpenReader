import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';
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
          render: (path, {required width, position}) async {
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
      render: (path, {required width, position}) async {
        renders++;
        return Uint8List.fromList([1]);
      },
    );
    final document = _document('/docs/deck.pptx');
    await Future.wait([service.getThumbnail(document), service.getThumbnail(document)]);
    expect(renders, 1);
  });

  test('a reading position draws its page, cached per page rather than per scroll', () async {
    final rendered = <ReadingPosition?>[];
    final service = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      render: (path, {required width, position}) async {
        rendered.add(position);
        return Uint8List.fromList([rendered.length]);
      },
    );
    final document = _document('/docs/report.pdf');

    final first = await service.getThumbnail(document);
    final page3 = await service.getThumbnail(
      document,
      position: {PositionKeys.pageNumber: 3, PositionKeys.pageCount: 9, PositionKeys.zoom: 1.5},
    );
    // Same page, another zoom: the cached picture.
    final page3Again = await service.getThumbnail(document, position: {PositionKeys.pageNumber: 3, PositionKeys.zoom: 2.0});
    // Only scroll offsets saved (an older position): the first page.
    final offsetOnly = await service.getThumbnail(document, position: {PositionKeys.scrollOffset: 400.0});

    expect(rendered, [null, {PositionKeys.pageNumber: 3}]);
    expect(page3!.path, isNot(first!.path));
    expect(page3Again!.path, page3.path);
    expect(offsetOnly!.path, first.path);
  });

  test('null when the kit has no preview or rendering fails', () async {
    final none = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      render: (path, {required width, position}) async => null,
    );
    expect(await none.getThumbnail(_document('/docs/broken.xlsx')), isNull);

    final failing = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      render: (path, {required width, position}) async => throw StateError('boom'),
    );
    expect(await failing.getThumbnail(_document('/docs/notes.txt')), isNull);
  });

  test('the same service redraws an edited file, not the preview from before the edit', () async {
    var renders = 0;
    final service = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      render: (path, {required width, position}) async => Uint8List.fromList([++renders]),
    );
    final before = await service.getThumbnail(_document('/docs/a.docx'));
    final after = await service.getThumbnail(_document('/docs/a.docx', modifiedAt: DateTime(2027)));
    expect(renders, 2);
    expect(after!.readAsBytesSync(), [2]);
    expect(after.path, isNot(before!.path));
  });

  test('no preview is tried again once failureRetryAfter has passed, not before', () async {
    Uint8List? next;
    var renders = 0;
    DocumentThumbnailService service(Duration retryAfter) => DocumentThumbnailService.withDependencies(
          pathService: _FakePathService(temp),
          failureRetryAfter: retryAfter,
          render: (path, {required width, position}) async {
            renders++;
            return next;
          },
        );
    final document = _document('/docs/copying.pptx');

    final patient = service(const Duration(hours: 1));
    expect(await patient.getThumbnail(document), isNull);
    next = Uint8List.fromList([7]);
    expect(await patient.getThumbnail(document), isNull);
    expect(renders, 1);

    next = null;
    final eager = service(Duration.zero);
    expect(await eager.getThumbnail(document), isNull);
    next = Uint8List.fromList([7]);
    expect((await eager.getThumbnail(document))!.readAsBytesSync(), [7]);
    expect(renders, 3);
  });

  test('cache files: stable 64-bit names, no partial files left, oldest pruned past the cap', () async {
    expect(DocumentThumbnailService.cacheFileName('a'), 'af63dc4c8601ec8c'); // FNV-1a 64 of "a".
    expect(DocumentThumbnailService.cacheFileName('a'), matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(DocumentThumbnailService.cacheFileName('b'), isNot(DocumentThumbnailService.cacheFileName('a')));

    final service = DocumentThumbnailService.withDependencies(
      pathService: _FakePathService(temp),
      maxCachedFiles: 3,
      render: (path, {required width, position}) async => Uint8List.fromList([1]),
    );
    File? newest;
    for (var i = 0; i < 6; i++) {
      newest = await service.getThumbnail(_document('/docs/$i.txt'));
    }
    final cached = Directory('${temp.path}/document_thumbnails').listSync().map((e) => e.path).toList();
    expect(cached, hasLength(3));
    expect(cached.where((path) => path.endsWith('.tmp')), isEmpty);
    expect(cached, contains(newest!.path));
  });

  test('previews a real non-PDF file through universal_document_viewer', () async {
    final path = '${temp.path}/notes.txt';
    File(path).writeAsStringSync('Shopping list\nMilk\nBread\n');
    final service = DocumentThumbnailService.withDependencies(pathService: _FakePathService(temp));

    final file = await service.getThumbnail(_document(path));
    expect(file, isNotNull);
    expect(file!.readAsBytesSync().sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
