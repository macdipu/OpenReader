import 'dart:io';

import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/services/utilities/file_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('openreader-metadata-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('reads fresh size and modified time for an existing file', () async {
    final file = File(p.join(root.path, 'report.pdf'));
    await file.writeAsString('fixture contents');
    final stat = await file.stat();

    final metadata = await FileMetadataService.instance.read(
      path: file.path,
      extension: 'pdf',
      category: DocumentCategory.pdf,
    );

    expect(metadata, isNotNull);
    expect(metadata!.path, file.path);
    expect(metadata.extension, 'pdf');
    expect(metadata.category, DocumentCategory.pdf);
    expect(metadata.sizeBytes, stat.size);
    expect(metadata.modifiedAt, stat.modified);
  });

  test('returns null when the file no longer exists (BRD 9.16 corner case)', () async {
    final metadata = await FileMetadataService.instance.read(
      path: p.join(root.path, 'missing.pdf'),
      extension: 'pdf',
      category: DocumentCategory.pdf,
    );
    expect(metadata, isNull);
  });
}
