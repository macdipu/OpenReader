import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/services/utilities/app_private_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory pkg;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('private_paths_');
    pkg = Directory(p.join(root.path, 'pkg'))..createSync();
  });
  tearDown(() => root.delete(recursive: true));

  test('a file inside a private folder is private, the folder itself is not "within"', () async {
    final paths = AppPrivatePaths.fixed([pkg.path]);
    expect(await paths.contains(p.join(pkg.path, 'a.pdf')), isTrue);
    expect(await paths.contains(p.join(pkg.path, 'sub', 'deep', 'a.pdf')), isTrue);
    expect(await paths.contains(p.join(root.path, 'other.pdf')), isFalse);
  });

  test('a sibling that shares the name prefix (pkg-evil vs pkg) is not private', () async {
    final paths = AppPrivatePaths.fixed([pkg.path]);
    expect(await paths.contains('${pkg.path}-evil${p.separator}a.pdf'), isFalse);
    expect(await paths.contains('${pkg.path}evil'), isFalse);
  });

  test('.. segments cannot escape the folder', () async {
    final paths = AppPrivatePaths.fixed([pkg.path]);
    expect(await paths.contains(p.join(pkg.path, '..', 'other.pdf')), isFalse);
    expect(await paths.contains(p.join(root.path, 'x', '..', 'pkg', 'a.pdf')), isTrue);
  });

  test('a trailing separator on the folder does not change the answer', () async {
    final paths = AppPrivatePaths.fixed(['${pkg.path}${p.separator}']);
    expect(await paths.contains(p.join(pkg.path, 'a.pdf')), isTrue);
    expect(await paths.contains('${pkg.path}-evil${p.separator}a.pdf'), isFalse);
  });

  test('an empty folder list makes nothing private', () async {
    expect(await AppPrivatePaths.fixed(const []).contains(p.join(pkg.path, 'a.pdf')), isFalse);
  });

  test('symlinks: a link inside pointing out is not private; a link outside pointing in is', () async {
    if (Platform.isWindows) return;
    final outside = Directory(p.join(root.path, 'outside'))..createSync();
    File(p.join(outside.path, 'secret.pdf')).writeAsStringSync('x');
    File(p.join(pkg.path, 'inner.pdf')).writeAsStringSync('x');
    final linkOut = Link(p.join(pkg.path, 'to_outside'))..createSync(outside.path);
    final linkIn = Link(p.join(outside.path, 'to_pkg'))..createSync(pkg.path);
    final paths = AppPrivatePaths.fixed([pkg.path]);
    expect(await paths.contains(p.join(linkOut.path, 'secret.pdf')), isFalse,
        reason: 'it lives outside even though its path starts inside');
    expect(await paths.contains(p.join(linkIn.path, 'inner.pdf')), isTrue);
  });

  test('a private folder reached through a symlink still matches the real path', () async {
    if (Platform.isWindows) return;
    final link = Link(p.join(root.path, 'link_to_pkg'))..createSync(pkg.path);
    File(p.join(pkg.path, 'a.pdf')).writeAsStringSync('x');
    final paths = AppPrivatePaths.fixed([link.path]);
    expect(await paths.contains(p.join(pkg.path, 'a.pdf')), isTrue);
  });

  test('a failed lookup is not cached: the next call retries and then caches', () async {
    var calls = 0;
    final paths = AppPrivatePaths(directories: () async {
      if (++calls == 1) throw const FileSystemException('lookup failed');
      return [pkg.path];
    });
    final file = p.join(pkg.path, 'a.pdf');
    expect(await paths.contains(file), isFalse);
    expect(await paths.contains(file), isTrue);
    expect(await paths.contains(file), isTrue);
    expect(calls, 2, reason: 'a good result is remembered');
  });
}
