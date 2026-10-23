import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/services/utilities/folder_browser_service.dart';
import 'package:path/path.dart' as p;

/// CR-OPENREADER-BROWSE: listing and on-demand search replace the storage scan.
void main() {
  late Directory root;
  late FolderBrowserService browser;

  Future<void> write(String relative, [String content = 'x']) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('openreader-browse-');
    await write('Report.pdf');
    await write('notes.txt');
    await write('photo.jpg'); // unsupported
    await write('empty.pdf', ''); // empty
    await write('.secret.pdf'); // hidden
    await write('Work/budget.xlsx');
    await write('Work/Deep/report-2.pdf');
    await write('.cache/report-hidden.pdf');
    browser = FolderBrowserService(roots: [BrowseRoot(name: 'Test', path: root.path)]);
  });
  tearDown(() => root.delete(recursive: true));

  test('roots come from the constructor in tests', () async {
    expect((await browser.roots()).single.path, root.path);
  });

  test('a folder lists its subfolders and supported, non-empty, visible documents', () async {
    final listing = await browser.list(root.path);
    expect(listing.denied, isFalse);
    expect(listing.folders.map((f) => p.basename(f.path)), ['Work']);
    expect(listing.documents.map((d) => d.displayName), unorderedEquals(['Report.pdf', 'notes.txt']));
    final report = listing.documents.firstWhere((d) => d.displayName == 'Report.pdf');
    expect(report.id, report.path);
    expect(report.category, DocumentCategory.pdf);
  });

  test('a folder that cannot be listed is reported as denied', () async {
    final listing = await browser.list(p.join(root.path, 'missing'));
    expect(listing.denied, isTrue);
  });

  test('search finds case-insensitive name matches below a folder, skipping hidden folders', () async {
    final found = await browser.search(root.path, 'REPORT').toList();
    expect(found.map((d) => d.displayName), unorderedEquals(['Report.pdf', 'report-2.pdf']));
    expect(await browser.search(p.join(root.path, 'Work'), 'report').map((d) => d.displayName).toList(), ['report-2.pdf']);
    expect(await browser.search(root.path, '   ').toList(), isEmpty);
  });

  test('search stops at the result cap', () async {
    for (var i = 0; i < FolderBrowserService.maxSearchResults + 5; i++) {
      await write('Many/match-$i.txt');
    }
    final found = await browser.search(root.path, 'match').toList();
    expect(found, hasLength(FolderBrowserService.maxSearchResults));
  });

  test('cancelling a search stops it', () async {
    final seen = <String>[];
    late StreamSubscription sub;
    final done = Completer<void>();
    sub = browser.search(root.path, 'report').listen((d) {
      seen.add(d.displayName);
      sub.cancel();
      done.complete();
    });
    await done.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen, hasLength(1));
  });

  test('search skips Android/data and Android/obb (review)', () async {
    await write('Android/data/com.app/report-in-app-data.pdf');
    await write('Android/obb/com.app/report-obb.pdf');
    await write('Android/media/report-media.pdf');
    final found = await browser.search(root.path, 'report').map((d) => d.displayName).toList();
    expect(found, isNot(contains('report-in-app-data.pdf')));
    expect(found, isNot(contains('report-obb.pdf')));
    expect(found, contains('report-media.pdf'));
  });

  test('symlinked folders and files are listed and searched once (review)', () async {
    await Link(p.join(root.path, 'WorkLink')).create(p.join(root.path, 'Work'));
    await Link(p.join(root.path, 'Linked.pdf')).create(p.join(root.path, 'Report.pdf'));
    final listing = await browser.list(root.path);
    expect(listing.folders.map((f) => p.basename(f.path)), containsAll(['Work', 'WorkLink']));
    expect(listing.documents.map((d) => d.displayName), contains('Linked.pdf'));
    final found = await browser.search(root.path, 'report-2').toList();
    expect(found, hasLength(1)); // Work and WorkLink are the same folder
  });
}
