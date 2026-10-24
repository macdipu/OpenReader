import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_reader_kit/testing.dart';
import 'package:open_reader_kit/word.dart';

String p(String text, {String props = '', String run = ''}) =>
    '<w:p><w:pPr>$props</w:pPr><w:r><w:rPr>$run</w:rPr><w:t xml:space="preserve">$text</w:t></w:r></w:p>';

List<WordParagraph> paragraphs(List<WordBlock> blocks) => blocks.whereType<WordParagraph>().toList();

void main() {
  group('python-docx fixture', () {
    late WordDocument doc;
    setUpAll(() => doc = DocxReader.read(File('test/fixtures/word/features.docx').readAsBytesSync()));
    WordParagraph find(String text) => paragraphs(doc.body).firstWhere((p) => p.plainText.contains(text));

    test('headings and run formatting', () {
      final heading = find('Quarterly Report');
      expect(heading.outlineLevel, 0);
      final runs = find('Plain').inlines.whereType<WordText>().toList();
      expect(runs.firstWhere((r) => r.text == 'bold').format.bold, isTrue);
      expect(runs.firstWhere((r) => r.text == 'italic').format.italic, isTrue);
      final red = runs.firstWhere((r) => r.text == 'red underline').format;
      expect(red.underline, UnderlineStyle.single);
      expect(red.color, 0xFFC00000);
      expect(red.size, 14);
    });

    test('links', () {
      final link = find('Visit').inlines.whereType<WordText>().firstWhere((r) => r.text == 'our site');
      expect(link.link, const WordLink(url: 'https://example.com/'));
    });

    test('alignment, tabs and line breaks keep all the text', () {
      expect(find('Centred').format.alignment, ParagraphAlignment.center);
      expect(find('left').plainText, 'left\tright\nsecond line');
    });

    test('lists are numbered from the document', () {
      expect(find('Apples').marker?.text, '•');
      expect(find('Pears').marker?.text, '•');
      expect([find('First').marker?.text, find('Second').marker?.text, find('Third').marker?.text], ['1.', '2.', '3.']);
    });

    test('tables: spans, vertical merges, borders', () {
      final table = doc.body.whereType<WordTable>().single;
      expect(table.columnWidths, hasLength(3));
      expect(table.rows, hasLength(3));
      final first = table.rows[0].cells;
      expect(first, hasLength(2));
      expect(first[0].columnSpan, 2);
      expect(paragraphs(first[0].blocks).first.plainText, 'wide');
      final tall = table.rows[1].cells[2];
      expect(tall.rowSpan, 2);
      expect(paragraphs(tall.blocks).first.plainText, 'tall');
      expect(table.rows[2].cells[2].covered, isTrue);
      expect(first[0].borders.top?.width, greaterThan(0), reason: 'Table Grid');
    });

    test('images', () {
      final image = paragraphs(doc.body).expand((p) => p.inlines).whereType<WordImage>().single;
      expect(image.width, closeTo(72, 0.1));
      expect(image.height, closeTo(36, 0.1));
      expect(doc.images[image.part], isNotNull);
    });

    test('page breaks, sections, headers and footers', () {
      expect(find('Before the break').inlines.whereType<WordBreak>().single.kind, BreakKind.page);
      expect(doc.sections, hasLength(2));
      expect(doc.body.whereType<WordSectionBreak>().single.sectionIndex, 0);
      expect(doc.sections[1].pageWidth, greaterThan(doc.sections[1].pageHeight));
      String text(List<WordBlock> blocks) => paragraphs(blocks).map((p) => p.plainText).join();
      expect(text(doc.sections[0].headers[HeaderFooterKind.defaultKind]!), 'Report header');
      expect(text(doc.sections[1].footers[HeaderFooterKind.defaultKind]!), 'Page footer', reason: 'inherited');
    });
  });

  group('built in memory', () {
    test('fields: results shown, instructions hidden, HYPERLINK fields link', () {
      final doc = DocxReader.read(buildDocx(
        '<w:p>'
        '<w:r><w:t xml:space="preserve">Page </w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>7</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
        '<w:r><w:t xml:space="preserve"> see </w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> HYPERLINK "https://a.example" </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>here</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
        '<w:fldSimple w:instr=" HYPERLINK \\l &quot;intro&quot; "><w:r><w:t>back</w:t></w:r></w:fldSimple>'
        '</w:p>',
      ));
      final paragraph = paragraphs(doc.body).single;
      expect(paragraph.plainText, 'Page 7 see hereback');
      final texts = paragraph.inlines.whereType<WordText>().toList();
      expect(texts.firstWhere((t) => t.text == 'here').link, const WordLink(url: 'https://a.example'));
      expect(texts.firstWhere((t) => t.text == 'back').link, const WordLink(anchor: 'intro'));
    });

    test('tracked changes show as accepted; hidden text is left out', () {
      final doc = DocxReader.read(buildDocx(
        '<w:p><w:r><w:t xml:space="preserve">kept </w:t></w:r>'
        '<w:ins><w:r><w:t>added</w:t></w:r></w:ins>'
        '<w:del><w:r><w:delText>removed</w:delText></w:r></w:del>'
        '<w:r><w:rPr><w:vanish/></w:rPr><w:t>secret</w:t></w:r></w:p>',
      ));
      expect(paragraphs(doc.body).single.plainText, 'kept added');
    });

    test('footnotes and endnotes: numbered by first reference', () {
      final doc = DocxReader.read(buildDocx(
        '<w:p><w:r><w:t>A</w:t></w:r><w:r><w:footnoteReference w:id="5"/></w:r>'
        '<w:r><w:t>B</w:t></w:r><w:r><w:footnoteReference w:id="2"/></w:r>'
        '<w:r><w:endnoteReference w:id="1"/></w:r></w:p>',
        footnotes: '<w:footnote w:type="separator" w:id="-1"><w:p/></w:footnote>'
            '<w:footnote w:id="2"><w:p><w:r><w:footnoteRef/></w:r><w:r><w:t xml:space="preserve"> Second</w:t></w:r></w:p></w:footnote>'
            '<w:footnote w:id="5"><w:p><w:r><w:footnoteRef/></w:r><w:r><w:t xml:space="preserve"> First</w:t></w:r></w:p></w:footnote>',
        endnotes: '<w:endnote w:id="1"><w:p><w:r><w:endnoteRef/></w:r><w:r><w:t xml:space="preserve"> End</w:t></w:r></w:p></w:endnote>',
      ));
      final refs = paragraphs(doc.body).single.inlines.whereType<WordNoteReference>().toList();
      expect([for (final r in refs) r.label], ['1', '2', 'i']);
      expect(paragraphs(doc.footnotes['5']!).single.plainText, '1 First');
      expect(paragraphs(doc.footnotes['2']!).single.plainText, '2 Second');
      expect(paragraphs(doc.endnotes['1']!).single.plainText, 'i End');
    });

    test('styles: default paragraph style, basedOn, toggles, character styles', () {
      final doc = DocxReader.read(buildDocx(
        p('body') + p('heading', props: '<w:pStyle w:val="H"/>') +
            '<w:p><w:pPr><w:pStyle w:val="H"/></w:pPr><w:r><w:rPr><w:rStyle w:val="Strong"/></w:rPr><w:t>toggled</w:t></w:r></w:p>',
        styles: '<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="20"/></w:rPr></w:rPrDefault></w:docDefaults>'
            '<w:style w:type="paragraph" w:default="1" w:styleId="Body"><w:rPr><w:color w:val="333333"/></w:rPr></w:style>'
            '<w:style w:type="paragraph" w:styleId="Base"><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>'
            '<w:style w:type="paragraph" w:styleId="H"><w:basedOn w:val="Base"/><w:pPr><w:outlineLvl w:val="1"/></w:pPr></w:style>'
            '<w:style w:type="character" w:styleId="Strong"><w:rPr><w:b/></w:rPr></w:style>',
      ));
      final [body, heading, toggled] = paragraphs(doc.body);
      final bodyRun = (body.inlines.single as WordText).format;
      expect(bodyRun.size, 10);
      expect(bodyRun.color, 0xFF333333, reason: 'w:default paragraph style, not "Normal"');
      final headingRun = (heading.inlines.single as WordText).format;
      expect(headingRun.bold, isTrue);
      expect(headingRun.size, 16);
      expect(heading.outlineLevel, 1);
      expect((toggled.inlines.single as WordText).format.bold, isFalse, reason: 'bold style XOR bold character style');
    });

    test('numbering: levels, templates, restarts, continuing lists', () {
      String item(String text, int numId, [int level = 0]) =>
          p(text, props: '<w:numPr><w:ilvl w:val="$level"/><w:numId w:val="$numId"/></w:numPr>');
      final doc = DocxReader.read(buildDocx(
        item('one', 1) + item('one.a', 1, 1) + item('one.b', 1, 1) + item('two', 1) + item('two.a', 1, 1) +
            p('break') + item('three', 1) + item('restart', 2),
        numbering: '<w:abstractNum w:abstractNumId="0">'
            '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl>'
            '<w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/><w:lvlText w:val="%1.%2)"/></w:lvl>'
            '</w:abstractNum>'
            '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
            '<w:num w:numId="2"><w:abstractNumId w:val="0"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>',
      ));
      expect([for (final p in paragraphs(doc.body)) p.marker?.text],
          ['1.', '1.a)', '1.b)', '2.', '2.a)', null, '3.', '1.']);
    });

    test('not a document', () {
      expect(() => DocxReader.read(buildXlsx(const [XlsxTestSheet('S', {'A1': 'x'})])), throwsA(isA<DocxFormatException>()));
    });
  });
}
