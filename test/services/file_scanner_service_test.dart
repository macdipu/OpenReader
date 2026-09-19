import 'dart:io';

import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/services/utilities/file_scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class UnreadableDirectory implements Directory {
  @override
  final String path;
  UnreadableDirectory(this.path);
  @override
  Future<bool> exists() async => true;
  @override
  Stream<FileSystemEntity> list(
          {bool recursive = false, bool followLinks = true}) =>
      Stream.error(FileSystemException('Permission denied', path));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('openreader-scan-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
      'discovers supported extensions, metadata and uppercase without writing files',
      () async {
    final files = <File>[];
    for (final extension in DocumentCategory.supportedExtensions) {
      final file =
          File(p.join(root.path, 'example.${extension.toUpperCase()}'));
      await file.writeAsString('fixture $extension');
      files.add(file);
    }
    await File(p.join(root.path, 'unknown.png')).writeAsString('ignore');
    await File(p.join(root.path, 'no-extension')).writeAsString('ignore');
    await File(p.join(root.path, 'trailing.')).writeAsString('ignore');
    await File(p.join(root.path, 'empty.pdf')).create();
    final before = {for (final f in files) f.path: await f.readAsBytes()};
    final scanned = await FileScannerService(roots: [root.path]).scan();
    expect(scanned, hasLength(files.length));
    for (final document in scanned) {
      expect(document.id, document.path);
      expect(document.displayName, p.basename(document.path));
      expect(
          document.category,
          DocumentCategory.fromExtension(
              p.extension(document.path).substring(1)));
      expect(document.sizeBytes, before[document.path]!.length);
      expect(document.modifiedAt, (await File(document.path).stat()).modified);
      expect(await File(document.path).readAsBytes(), before[document.path]);
    }
  });

  test('deduplicates overlapping roots and skips missing roots and symlinks',
      () async {
    final nested = await Directory(p.join(root.path, 'nested')).create();
    final file = await File(p.join(nested.path, 'a.pdf')).writeAsString('pdf');
    await Link(p.join(root.path, 'linked.pdf')).create(file.path);
    await Link(p.join(root.path, 'loop')).create(root.path);
    final result = await FileScannerService(
        roots: [nested.path, root.path, p.join(root.path, 'missing')]).scan();
    expect(result.map((d) => d.path), [file.path]);
  });

  test('includes depth eight but not depth nine', () async {
    var directory = root;
    for (var depth = 1; depth <= 9; depth++) {
      directory = await Directory(p.join(directory.path, '$depth')).create();
      await File(p.join(directory.path, '$depth.txt')).writeAsString('text');
    }
    final result = await FileScannerService(roots: [root.path]).scan();
    expect(result, hasLength(8));
    expect(result.map((d) => d.displayName), contains('8.txt'));
    expect(result.map((d) => d.displayName), isNot(contains('9.txt')));
  });

  test('skips an unreadable root and still scans subsequent roots', () async {
    final good = await File(p.join(root.path, 'ok.txt')).writeAsString('ok');
    final actualRoot = root;
    final result = await IOOverrides.runZoned(
      () => FileScannerService(roots: ['/unreadable', root.path]).scan(),
      createDirectory: (path) =>
          path == '/unreadable' ? UnreadableDirectory(path) : actualRoot,
    );
    expect(result.map((d) => d.path), [good.path]);
  });
}
