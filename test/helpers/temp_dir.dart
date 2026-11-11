import 'dart:io';

/// Deletes a test's temp folder, retrying while something still has a file in it open.
///
/// On Windows a file that is still open cannot be deleted, and a reader controller opens its
/// document on a background isolate that can still be holding it when the test finishes; a bare
/// `delete` then fails the test at random. Gives up quietly after about a second: leftover temp
/// files are harmless, a flaky test is not.
Future<void> deleteTempDir(Directory dir) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
