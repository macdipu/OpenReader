import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:universal_document_viewer/ocr.dart';

/// Runs the Tesseract command line: arguments in, process result out. A seam
/// for tests.
typedef TesseractRun = Future<ProcessResult> Function(String executable, List<String> arguments);

/// OCR on Linux through the system's Tesseract (CR-READER-SELECT-OCR SO-14).
///
/// Linux has no built-in text recognition, so this uses the `tesseract`
/// program when it is installed (the .deb and .rpm packages recommend it) and
/// reports itself unavailable when it is not, which hides OCR. It runs on the
/// device; nothing is sent anywhere. The page image goes to a temporary file
/// that is deleted straight after.
///
/// Tesseract does not detect the language: it reads with the language asked
/// for ([OcrInput.languageHints]), else English if installed, else the first
/// installed language. [languages] and [run] are for tests.
class TesseractTextRecognizer extends TextRecognizer {
  /// Looks for `tesseract` once, now.
  TesseractTextRecognizer({this.executable = 'tesseract', List<String>? languages, TesseractRun? run, bool? available})
    : _run = run ?? ((exe, args) => Process.run(exe, args, stdoutEncoding: utf8, stderrEncoding: utf8)),
      _languages = languages ?? (available == false ? const [] : _probeLanguages(executable)),
      _available = available;

  /// The program to run.
  final String executable;
  final TesseractRun _run;
  final List<String> _languages;
  final bool? _available;

  /// Languages whose data Tesseract has installed (its codes: `eng`, `deu`).
  List<String> get installedLanguages => _languages;

  @override
  bool get isAvailable => (_available ?? Platform.isLinux) && _languages.isNotEmpty;

  @override
  Future<OcrResult> recognize(OcrInput input) async {
    final language = chooseTesseractLanguage(input.languageHints, _languages);
    final folder = await Directory.systemTemp.createTemp('openreader-ocr-');
    try {
      final file = File('${folder.path}/page.png');
      await file.writeAsBytes(input.png, flush: true);
      final reply = await _run(executable, [file.path, 'stdout', '-l', language, '--psm', '3', 'tsv']).timeout(
        const Duration(minutes: 2),
      );
      if (reply.exitCode != 0) {
        throw ProcessException(executable, const [], '${reply.stderr}'.trim(), reply.exitCode);
      }
      return ocrResultFromTesseractTsv('${reply.stdout}', language: language);
    } finally {
      // The page image is the user's document content: never leave it behind.
      try {
        await folder.delete(recursive: true);
      } catch (_) {}
    }
  }

  static List<String> _probeLanguages(String executable) {
    if (!Platform.isLinux) return const [];
    try {
      final reply = Process.runSync(executable, ['--list-langs'], stdoutEncoding: utf8, stderrEncoding: utf8);
      return reply.exitCode == 0 ? parseTesseractLanguages('${reply.stdout}${reply.stderr}') : const [];
    } on ProcessException {
      return const [];
    }
  }
}

/// The language codes in `tesseract --list-langs` output, without the header
/// line and without `osd` (script detection data, not a language).
List<String> parseTesseractLanguages(String output) => [
  for (final line in const LineSplitter().convert(output))
    if (RegExp(r'^[A-Za-z0-9_]+$').hasMatch(line.trim()) && line.trim() != 'osd') line.trim(),
];

const _twoToThree = {
  'en': 'eng',
  'de': 'deu',
  'fr': 'fra',
  'es': 'spa',
  'it': 'ita',
  'pt': 'por',
  'nl': 'nld',
  'ru': 'rus',
  'ar': 'ara',
  'hi': 'hin',
  'bn': 'ben',
  'ja': 'jpn',
  'ko': 'kor',
  'zh': 'chi_sim',
  'tr': 'tur',
  'pl': 'pol',
  'sv': 'swe',
  'uk': 'ukr',
};

/// The Tesseract language to read with: the first hint that is installed
/// (hints may be "en" or "eng"), else English, else the first installed one.
String chooseTesseractLanguage(List<String> hints, List<String> installed) {
  for (final hint in hints) {
    final base = hint.split(RegExp('[-_]')).first.toLowerCase();
    final code = _twoToThree[base] ?? base;
    if (installed.contains(code)) return code;
  }
  if (installed.contains('eng')) return 'eng';
  return installed.isEmpty ? 'eng' : installed.first;
}

/// A page's lines from Tesseract's TSV output: words (level 5) grouped by
/// block, paragraph and line, a box around each line, confidence the mean of
/// its words'.
OcrResult ocrResultFromTesseractTsv(String tsv, {String? language}) {
  final lines = <OcrLine>[];
  String? key;
  final words = <String>[];
  Rect? box;
  var confidenceSum = 0.0;
  var confidenceCount = 0;

  void flush() {
    if (box != null && words.isNotEmpty) {
      lines.add(
        OcrLine(
          text: words.join(' '),
          rect: box!,
          confidence: confidenceCount == 0 ? null : confidenceSum / confidenceCount / 100,
        ),
      );
    }
    words.clear();
    box = null;
    confidenceSum = 0;
    confidenceCount = 0;
  }

  for (final row in const LineSplitter().convert(tsv)) {
    final cells = row.split('\t');
    // level page block par line word left top width height conf text
    if (cells.length < 12 || cells[0] != '5') continue;
    final text = cells.sublist(11).join('\t').trim();
    if (text.isEmpty) continue;
    final lineKey = '${cells[2]}.${cells[3]}.${cells[4]}';
    if (lineKey != key) {
      flush();
      key = lineKey;
    }
    final left = double.tryParse(cells[6]) ?? 0;
    final top = double.tryParse(cells[7]) ?? 0;
    final word = Rect.fromLTWH(left, top, double.tryParse(cells[8]) ?? 0, double.tryParse(cells[9]) ?? 0);
    box = box == null ? word : box!.expandToInclude(word);
    words.add(text);
    final confidence = double.tryParse(cells[10]) ?? -1;
    if (confidence >= 0) {
      confidenceSum += confidence;
      confidenceCount++;
    }
  }
  flush();

  final back = {for (final e in _twoToThree.entries) e.value: e.key};
  return OcrResult(lines: lines, detectedLanguage: language == null ? null : (back[language] ?? language));
}
