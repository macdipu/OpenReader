import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// One piece of slide content, in reading order.
sealed class PptxBlock {
  const PptxBlock();
}

/// A text paragraph; [level] is the bullet indent (0 = top level).
class PptxParagraph extends PptxBlock {
  const PptxParagraph(this.text, {this.level = 0});

  final String text;
  final int level;
}

/// A table, as rows of cell text.
class PptxTable extends PptxBlock {
  const PptxTable(this.rows);

  final List<List<String>> rows;
}

/// A picture placed on the slide.
class PptxImage extends PptxBlock {
  const PptxImage(this.bytes);

  final Uint8List bytes;
}

class PptxSlide {
  const PptxSlide({this.title, this.blocks = const []});

  final String? title;
  final List<PptxBlock> blocks;

  /// Everything searchable on the slide.
  String get text => [
        if (title case final title?) title,
        for (final block in blocks)
          if (block is PptxParagraph)
            block.text
          else if (block is PptxTable)
            for (final row in block.rows) row.join(' '),
      ].join('\n');
}

class PptxPresentation {
  const PptxPresentation(this.slides);

  final List<PptxSlide> slides;
}

/// Not a readable PowerPoint (.pptx) package.
class PptxFormatException implements Exception {
  const PptxFormatException(this.message);

  final String message;

  @override
  String toString() => 'PptxFormatException: $message';
}

/// Reads a `.pptx` (Office Open XML) into slides of text, tables and
/// pictures (CR-OPENREADER-PPTX). It is a reading view, not a layout engine:
/// positions, themes and animations are not reproduced.
class PptxParser {
  const PptxParser._();

  static const _ns = (
    p: 'http://schemas.openxmlformats.org/presentationml/2006/main',
    a: 'http://schemas.openxmlformats.org/drawingml/2006/main',
    r: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
  );

  /// Image types Flutter can decode; others (EMF/WMF vector art) are skipped.
  static const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'};

  static PptxPresentation parse(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const PptxFormatException('Not a ZIP package');
    }
    final files = {
      for (final f in archive.files)
        if (f.isFile) f.name: f
    };

    String? readText(String name) {
      final file = files[name];
      if (file == null) return null;
      final content = file.readBytes();
      return content == null ? null : utf8.decode(content, allowMalformed: true);
    }

    final presentationXml = readText('ppt/presentation.xml');
    if (presentationXml == null) throw const PptxFormatException('No ppt/presentation.xml');
    final presentation = _xml(presentationXml);
    final presentationRels = _relationships(readText('ppt/_rels/presentation.xml.rels'), 'ppt');

    final slidePaths = <String>[
      for (final id in presentation.findAllElements('sldId', namespaceUri: _ns.p))
        if (presentationRels[id.getAttribute('id', namespaceUri: _ns.r)] case final target?) target,
    ];

    final slides = <PptxSlide>[];
    for (final path in slidePaths) {
      final xml = readText(path);
      if (xml == null) continue;
      final rels = _relationships(readText(_relsPathFor(path)), p.posix.dirname(path));
      slides.add(_slide(_xml(xml), rels, (name) => files[name]?.readBytes()));
    }
    return PptxPresentation(slides);
  }

  static XmlDocument _xml(String source) {
    try {
      return XmlDocument.parse(source);
    } on XmlException {
      throw const PptxFormatException('Malformed slide XML');
    }
  }

  /// `ppt/slides/slide1.xml` -> `ppt/slides/_rels/slide1.xml.rels`
  static String _relsPathFor(String part) =>
      p.posix.join(p.posix.dirname(part), '_rels', '${p.posix.basename(part)}.rels');

  /// Relationship id -> package path, resolved against [baseDir].
  static Map<String, String> _relationships(String? source, String baseDir) {
    if (source == null) return const {};
    final doc = _xml(source);
    return {
      for (final rel in doc.findAllElements('Relationship'))
        if (rel.getAttribute('Id') case final id?)
          if (rel.getAttribute('Target') case final target?)
            if (rel.getAttribute('TargetMode') != 'External')
              id: p.posix.normalize(target.startsWith('/') ? target.substring(1) : p.posix.join(baseDir, target)),
    };
  }

  static PptxSlide _slide(XmlDocument doc, Map<String, String> rels, List<int>? Function(String) read) {
    String? title;
    final blocks = <PptxBlock>[];
    final tree = doc.findAllElements('spTree', namespaceUri: _ns.p).firstOrNull;
    if (tree == null) return const PptxSlide();

    void visit(XmlElement element) {
      for (final child in element.childElements) {
        if (child.namespaceUri == _ns.p && child.localName == 'sp') {
          final paragraphs = _paragraphs(child);
          if (paragraphs.isEmpty) continue;
          if (title == null && _isTitle(child)) {
            title = paragraphs.map((para) => para.text).join(' ');
          } else {
            blocks.addAll(paragraphs);
          }
        } else if (child.namespaceUri == _ns.p && child.localName == 'grpSp') {
          visit(child);
        } else if (child.namespaceUri == _ns.p && child.localName == 'graphicFrame') {
          final table = child.findAllElements('tbl', namespaceUri: _ns.a).firstOrNull;
          if (table != null) {
            final rows = [
              for (final row in table.findElements('tr', namespaceUri: _ns.a))
                [for (final cell in row.findElements('tc', namespaceUri: _ns.a)) _text(cell).trim()],
            ];
            if (rows.any((row) => row.isNotEmpty)) blocks.add(PptxTable(rows));
          }
        } else if (child.namespaceUri == _ns.p && child.localName == 'pic') {
          final embed = child
              .findAllElements('blip', namespaceUri: _ns.a)
              .firstOrNull
              ?.getAttribute('embed', namespaceUri: _ns.r);
          final path = embed == null ? null : rels[embed];
          if (path != null && _imageExtensions.contains(p.posix.extension(path).toLowerCase())) {
            final bytes = read(path);
            if (bytes != null && bytes.isNotEmpty) blocks.add(PptxImage(Uint8List.fromList(bytes)));
          }
        }
      }
    }

    visit(tree);
    return PptxSlide(title: title, blocks: blocks);
  }

  static bool _isTitle(XmlElement shape) {
    final type = shape.findAllElements('ph', namespaceUri: _ns.p).firstOrNull?.getAttribute('type');
    return type == 'title' || type == 'ctrTitle';
  }

  static List<PptxParagraph> _paragraphs(XmlElement shape) {
    final body = shape.findAllElements('txBody', namespaceUri: _ns.p).firstOrNull;
    if (body == null) return const [];
    return [
      for (final para in body.findElements('p', namespaceUri: _ns.a))
        if (_text(para).trim() case final text when text.isNotEmpty)
          PptxParagraph(
            text,
            level:
                int.tryParse(para.findElements('pPr', namespaceUri: _ns.a).firstOrNull?.getAttribute('lvl') ?? '') ?? 0,
          ),
    ];
  }

  /// Text runs (`a:t`) in order; line breaks (`a:br`) become newlines.
  static String _text(XmlElement element) {
    final buffer = StringBuffer();
    for (final node in element.descendantElements) {
      if (node.namespaceUri != _ns.a) continue;
      if (node.localName == 't') buffer.write(node.innerText);
      if (node.localName == 'br') buffer.write('\n');
    }
    return buffer.toString();
  }
}
