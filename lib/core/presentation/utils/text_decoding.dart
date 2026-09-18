import 'dart:convert';
import 'dart:typed_data';

/// UTF-8 first; Latin-1 (which accepts every byte) as the fallback for a
/// non-UTF-8 file. Not full charset auto-detection - shared by the Text and
/// CSV readers (`FEATURE-OPENDOCS-P4/SRS.md` Unresolved Question 3's
/// deliberately narrow scope).
String decodeTextBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}
