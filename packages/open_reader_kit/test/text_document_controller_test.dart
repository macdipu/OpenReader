import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_reader_kit/open_reader_kit.dart';
import 'package:open_reader_kit/text.dart';

void main() {
  Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

  test('splits text into lines, decoding UTF-8', () {
    final doc = TextDocumentController()..load(text('héllo\nworld'));
    expect(doc.error, isNull);
    expect(doc.lines, ['héllo', 'world']);
  });

  test('falls back to Latin-1 for non-UTF-8 bytes', () {
    final doc = TextDocumentController()..load(Uint8List.fromList([0x63, 0x61, 0x66, 0xE9]));
    expect(doc.lines, ['café']);
  });

  test('refuses binary content as corrupted', () {
    final doc = TextDocumentController()..load(Uint8List.fromList([0x50, 0x4B, 0x00, 0x01]));
    expect(doc.error, DocumentLoadError.corrupted);
  });

  test('restores and reports the scroll offset', () {
    ReadingPosition? reported;
    final doc = TextDocumentController(
      initialPosition: {PositionKeys.scrollOffset: 120.5},
      onPositionChanged: (p) => reported = p,
    );
    expect(doc.initialScrollOffset, 120.5);
    doc.onScrolled(40);
    expect(reported, {PositionKeys.scrollOffset: 40.0});
  });

  test('search matches lines in any case and cycles', () {
    final doc = TextDocumentController()..load(text('Alpha\nbeta\nALPHA again'));
    doc.search('alpha');
    expect(doc.matches, [0, 2]);
    expect(doc.currentMatch, 0);
    doc.nextMatch();
    expect(doc.currentMatch, 1);
    doc.nextMatch();
    expect(doc.currentMatch, 0);
    doc.previousMatch();
    expect(doc.currentMatch, 1);
    doc.clearSearch();
    expect(doc.matches, isEmpty);
  });
}
