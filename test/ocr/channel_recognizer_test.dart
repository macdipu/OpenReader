
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/ocr/channel_text_recognizer.dart';
import 'package:universal_document_viewer/ocr.dart';

/// CR-READER-SELECT-OCR SO-14: the platform-channel recognizer (Apple Vision
/// on macOS). The native side is tried by hand; this checks the Dart side of
/// the contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('openreader/ocr-test');
  final calls = <MethodCall>[];

  setUp(calls.clear);
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  void reply(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  OcrInput input({List<String> hints = const []}) =>
      OcrInput(png: Uint8List.fromList([1, 2, 3]), width: 100, height: 50, languageHints: hints);

  test('sends the PNG and language hints, reads lines, boxes, confidence and language', () async {
    reply(
      (_) => {
        'lines': [
          {'text': 'Hello', 'left': 10.0, 'top': 20.0, 'right': 110.0, 'bottom': 60.0, 'confidence': 0.98},
          {'text': '   ', 'left': 0, 'top': 0, 'right': 1, 'bottom': 1},
          {'text': 'World', 'left': 10, 'top': 70, 'right': 90, 'bottom': 100},
        ],
        'language': 'en',
      },
    );
    final result = await ChannelTextRecognizer(channel: channel, available: true).recognize(input(hints: ['en']));

    expect(calls.single.method, 'recognize');
    expect((calls.single.arguments as Map)['png'], Uint8List.fromList([1, 2, 3]));
    expect((calls.single.arguments as Map)['languages'], ['en']);
    expect(result.lines.map((l) => l.text), ['Hello', 'World']);
    expect(result.lines.first.rect, const Rect.fromLTRB(10, 20, 110, 60));
    expect(result.lines.first.confidence, 0.98);
    expect(result.lines.last.confidence, isNull);
    expect(result.detectedLanguage, 'en');
  });

  test('a null or empty language is no language, and an empty reply is no text', () async {
    reply((_) => {'lines': <Object?>[], 'language': null});
    final result = await ChannelTextRecognizer(channel: channel, available: true).recognize(input());
    expect(result.isEmpty, isTrue);
    expect(result.detectedLanguage, isNull);
    expect(ocrResultFromChannel({'language': ''}).detectedLanguage, isNull);
    expect(ocrResultFromChannel(const {}).lines, isEmpty);
  });

  test('a native failure surfaces as an exception for the viewer to report', () async {
    reply((_) => throw PlatformException(code: 'ocr_failed', message: 'bad image'));
    await expectLater(
      ChannelTextRecognizer(channel: channel, available: true).recognize(input()),
      throwsA(isA<PlatformException>()),
    );
  });

  test('availability and language detection follow how it is built', () {
    expect(ChannelTextRecognizer(available: false).isAvailable, isFalse);
    final recognizer = ChannelTextRecognizer(available: true);
    expect(recognizer.isAvailable, isTrue);
    expect(recognizer.supportsAutoDetect, isTrue);
    expect(ChannelTextRecognizer(available: true, detectsLanguage: false).supportsAutoDetect, isFalse);
  });
}
