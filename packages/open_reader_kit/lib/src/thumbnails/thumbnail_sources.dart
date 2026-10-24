import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../common/zip_safety_guard.dart';

/// Reads the Office (ZIP) file at [path] and [parse]s it in a background
/// isolate, after [ZipSafetyGuard] - so only [parse]'s result crosses back
/// to the UI isolate. Null when the guard refuses the file. [parse] should
/// keep only what the first page needs.
Future<T?> parseOfficeFile<T>(String path, T Function(Uint8List bytes) parse) => Isolate.run(() {
      final bytes = File(path).readAsBytesSync();
      if (ZipSafetyGuard.check(bytes) != ZipSafetyResult.safe) return null;
      return parse(bytes);
    });

/// The first [headBytes] of the text file at [path], cut after its last
/// whole line (so a multi-byte character isn't split); null for a file
/// over [maxBytes], which its reader would refuse too.
Future<Uint8List?> readTextHead(String path, {required int maxBytes, int headBytes = 32 * 1024}) async {
  final file = File(path);
  final length = await file.length();
  if (length > maxBytes) return null;
  final handle = await file.open();
  try {
    final head = await handle.read(math.min(length, headBytes));
    if (length <= headBytes) return head;
    final lastLineEnd = head.lastIndexOf(0x0A);
    return lastLineEnd > 0 ? Uint8List.sublistView(head, 0, lastLineEnd) : head;
  } finally {
    await handle.close();
  }
}
