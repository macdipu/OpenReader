import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../engines/word/word_model.dart';
import 'word_document_layout.dart';
import 'word_search_controller.dart';

/// What every block widget of a Word document needs, provided once above
/// them: the layout (paragraph numbers), search highlights, images, and
/// what tapping a link or a note mark does.
class WordScope extends InheritedWidget {
  const WordScope({
    super.key,
    required this.layout,
    required this.search,
    required this.onLink,
    required this.onNote,
    required this.anchors,
    required super.child,
  });

  /// Points -> logical pixels (1 pt = 1/72 in, 1 px = 1/96 in).
  static const double scale = 96 / 72;

  final WordDocumentLayout layout;
  final WordSearchController search;
  final void Function(WordLink link) onLink;
  final void Function(WordNoteReference note) onNote;

  /// Paragraph number -> the context of its widget while it's built, so a
  /// jump can scroll it into view.
  final Map<int, BuildContext> anchors;

  static WordScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WordScope>()!;

  @override
  bool updateShouldNotify(WordScope oldWidget) =>
      layout != oldWidget.layout || search != oldWidget.search;
}

/// One block: a paragraph, a table, or a section break.
class WordBlockView extends StatelessWidget {
  const WordBlockView(this.block, {super.key});

  final WordBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
        final WordParagraph paragraph => WordParagraphView(paragraph),
        final WordTable table => WordTableView(table),
        WordSectionBreak() => const Divider(height: 24),
      };
}

// --- Paragraphs ----------------------------------------------------------------

class WordParagraphView extends StatefulWidget {
  const WordParagraphView(this.paragraph, {super.key});

  final WordParagraph paragraph;

  @override
  State<WordParagraphView> createState() => _WordParagraphViewState();
}

class _WordParagraphViewState extends State<WordParagraphView> {
  /// Owned here and disposed: one per link or note mark in the paragraph.
  final _recognizers = <TapGestureRecognizer>[];
  int? _number;
  WordScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(WordParagraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paragraph != widget.paragraph) _register();
  }

  void _register() {
    _unregister();
    _scope = WordScope.of(context);
    _number = _scope!.layout.numberOf(widget.paragraph);
    if (_number != null) _scope!.anchors[_number!] = context;
  }

  void _unregister() {
    if (_number != null && identical(_scope?.anchors[_number!], context)) _scope!.anchors.remove(_number);
  }

  @override
  void dispose() {
    _unregister();
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    final scope = WordScope.of(context);
    return ListenableBuilder(
      listenable: scope.search,
      builder: (context, _) {
        for (final recognizer in _recognizers) {
          recognizer.dispose();
        }
        _recognizers.clear();
        return _buildParagraph(context, scope);
      },
    );
  }

  Widget _buildParagraph(BuildContext context, WordScope scope) {
    final paragraph = widget.paragraph;
    final format = paragraph.format;
    final theme = Theme.of(context);
    final highlights = _number == null ? const <WordHighlight>[] : scope.search.highlightsOf(_number!);
    final background = format.fill == null ? null : Color(format.fill!);
    final firstSize = paragraph.inlines.whereType<WordText>().firstOrNull?.format.size ?? paragraph.marker?.format.size ?? 11;

    final lineHeight = switch (format.lineSpacingRule) {
      // Word's single spacing is about 1.15x the font size for its default
      // fonts; multiples scale that.
      LineSpacingRule.auto => 1.15 * format.lineSpacing,
      LineSpacingRule.exact => (format.lineSpacing / firstSize).clamp(0.8, 4.0),
      LineSpacingRule.atLeast => math.max(1.15, format.lineSpacing / firstSize).clamp(1.0, 4.0),
    };

    final spans = _spans(context, scope, highlights, background);
    final markerInline = paragraph.marker != null && paragraph.marker!.suffix != ListMarkerSuffix.tab;
    final text = Text.rich(
      TextSpan(
        style: TextStyle(height: lineHeight, color: theme.colorScheme.onSurface),
        children: [
          if (markerInline)
            TextSpan(
              text: paragraph.marker!.text + (paragraph.marker!.suffix == ListMarkerSuffix.space ? ' ' : ''),
              style: _textStyle(context, paragraph.marker!.format, background, link: false),
            ),
          if (!markerInline && paragraph.marker == null && format.firstLineIndent > 0)
            WidgetSpan(child: SizedBox(width: format.firstLineIndent * WordScope.scale)),
          ...spans,
          // An empty paragraph still takes a line, as in Word.
          if (spans.isEmpty) const TextSpan(text: ' '),
        ],
      ),
      textAlign: switch (format.alignment) {
        ParagraphAlignment.left => TextAlign.start,
        ParagraphAlignment.center => TextAlign.center,
        ParagraphAlignment.right => TextAlign.end,
        ParagraphAlignment.justify => TextAlign.justify,
      },
      textDirection: format.rightToLeft ? TextDirection.rtl : null,
    );

    Widget body = text;
    final marker = paragraph.marker;
    var left = format.indentLeft;
    if (marker != null && marker.suffix == ListMarkerSuffix.tab) {
      // The marker hangs in the space the hanging indent leaves.
      final hanging = format.firstLineIndent < 0 ? -format.firstLineIndent : 18.0;
      left = math.max(0, format.indentLeft - hanging);
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: hanging * WordScope.scale,
            child: Text(
              marker.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: _textStyle(context, marker.format, background, link: false).copyWith(height: lineHeight),
            ),
          ),
          Expanded(child: text),
        ],
      );
    }

    final hasPageBreak = paragraph.inlines.any((i) => i is WordBreak && i.kind == BreakKind.page);
    final borders = [format.borderTop, format.borderBottom, format.borderLeft, format.borderRight];
    Widget result = LayoutBuilder(
      builder: (context, constraints) {
        // Deep indents are scaled for a page, not a phone: never let them
        // take more than 40% of the width.
        final maxIndent = constraints.maxWidth * 0.4;
        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: math.min(left * WordScope.scale, maxIndent),
            end: math.min(format.indentRight * WordScope.scale, maxIndent / 2),
          ),
          child: body,
        );
      },
    );
    if (background != null || borders.any((b) => b != null && b.width > 0)) {
      BorderSide side(BorderLine? line) => line == null || line.width == 0
          ? BorderSide.none
          : BorderSide(
              width: math.max(0.5, line.width * WordScope.scale),
              color: line.color == null ? theme.colorScheme.onSurface : Color(line.color!),
            );
      result = DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            top: side(format.borderTop),
            bottom: side(format.borderBottom),
            left: side(format.borderLeft),
            right: side(format.borderRight),
          ),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4), child: result),
      );
    }
    result = Padding(
      padding: EdgeInsets.only(
        top: format.spaceBefore * WordScope.scale,
        bottom: format.spaceAfter * WordScope.scale,
      ),
      child: result,
    );
    if (paragraph.outlineLevel != null) result = Semantics(header: true, child: result);
    if (hasPageBreak) result = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [result, const Divider(height: 24)]);
    return result;
  }

  /// The paragraph's inline content as spans, split where search
  /// highlights start and end. Offsets follow [WordParagraph.plainText].
  List<InlineSpan> _spans(BuildContext context, WordScope scope, List<WordHighlight> highlights, Color? paragraphFill) {
    final scheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var offset = 0;

    Color? highlightAt(int start, int end) {
      for (final h in highlights) {
        if (h.start < end && start < h.end) {
          return h.current ? scheme.tertiaryContainer : scheme.secondaryContainer;
        }
      }
      return null;
    }

    for (final inline in widget.paragraph.inlines) {
      switch (inline) {
        case WordText(:final text, :final format, :final link):
          final style = _textStyle(context, format, paragraphFill, link: link != null);
          final recognizer = link == null ? null : _tap(() => scope.onLink(link));
          // Cut points: the run's ends and any highlight edge inside it.
          final cuts = <int>{0, text.length};
          for (final h in highlights) {
            if (h.start > offset && h.start < offset + text.length) cuts.add(h.start - offset);
            if (h.end > offset && h.end < offset + text.length) cuts.add(h.end - offset);
          }
          final points = cuts.toList()..sort();
          for (var i = 0; i + 1 < points.length; i++) {
            final piece = text.substring(points[i], points[i + 1]);
            final mark = highlightAt(offset + points[i], offset + points[i + 1]);
            final shown = format.allCaps ? piece.toUpperCase() : piece;
            final pieceStyle = mark == null ? style : style.copyWith(backgroundColor: mark, color: scheme.onSurface);
            if (format.verticalPosition == VerticalTextPosition.baseline) {
              spans.add(TextSpan(text: shown, style: pieceStyle, recognizer: recognizer));
            } else {
              spans.add(_raised(shown, pieceStyle, superscript: format.verticalPosition == VerticalTextPosition.superscript));
            }
          }
          offset += text.length;
        case WordTab(:final format):
          spans.add(TextSpan(text: '  ', style: _textStyle(context, format, paragraphFill, link: false)));
          offset += 1;
        case WordBreak():
          spans.add(const TextSpan(text: '\n'));
          offset += 1;
        case WordNoteReference(:final label, :final format):
          final mark = highlightAt(offset, offset + label.length);
          final style = _textStyle(context, format, paragraphFill, link: true);
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Semantics(
              button: true,
              label: 'Note $label',
              child: GestureDetector(
                onTap: () => scope.onNote(inline),
                child: Text(
                  label,
                  style: style.copyWith(
                    fontSize: (style.fontSize ?? 14) * 0.7,
                    backgroundColor: mark,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ));
          offset += label.length;
        case WordImage():
          spans.add(WidgetSpan(alignment: PlaceholderAlignment.bottom, child: WordImageView(inline)));
        case WordBookmark():
          break;
      }
    }
    return spans;
  }

  /// Superscript or subscript text: smaller, and raised or lowered.
  static InlineSpan _raised(String text, TextStyle style, {required bool superscript}) => WidgetSpan(
        alignment: superscript ? PlaceholderAlignment.top : PlaceholderAlignment.bottom,
        child: Text(text, style: style.copyWith(fontSize: (style.fontSize ?? 14) * 0.65)),
      );
}

/// A run's formatting as a [TextStyle]. The file's colours are kept where
/// they stay readable against what's behind them (fill, highlight, or the
/// theme surface); otherwise the theme's text colour is used.
TextStyle _textStyle(BuildContext context, RunFormat format, Color? paragraphFill, {required bool link}) {
  final scheme = Theme.of(context).colorScheme;
  final runBackground = format.highlight ?? format.fill;
  final behind = runBackground != null ? Color(runBackground) : (paragraphFill ?? scheme.surface);
  // A link without its own colour takes the document's hyperlink colour,
  // as in Word; the theme's primary where that wouldn't be readable.
  final own = format.color != null
      ? Color(format.color!)
      : (link ? Color(WordScope.of(context).layout.document.linkColor) : null);
  Color color;
  if (own != null && contrastRatio(own, behind) >= 3) {
    color = own;
  } else if (link && format.color == null) {
    color = scheme.primary;
  } else if (runBackground != null || paragraphFill != null) {
    color = behind.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  } else {
    color = scheme.onSurface;
  }
  final decorations = [
    if (format.underline != UnderlineStyle.none || link) TextDecoration.underline,
    if (format.strike || format.doubleStrike) TextDecoration.lineThrough,
  ];
  return TextStyle(
    fontSize: format.size * WordScope.scale,
    fontWeight: format.bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: format.italic ? FontStyle.italic : FontStyle.normal,
    color: color,
    backgroundColor: runBackground == null ? null : Color(runBackground),
    decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
    decorationStyle: switch (format.underline) {
      UnderlineStyle.double => TextDecorationStyle.double,
      UnderlineStyle.dotted => TextDecorationStyle.dotted,
      UnderlineStyle.dashed => TextDecorationStyle.dashed,
      UnderlineStyle.wavy => TextDecorationStyle.wavy,
      _ => format.doubleStrike ? TextDecorationStyle.double : null,
    },
    decorationColor: color,
    fontFamily: format.font,
    fontFamilyFallback: _fallbackFonts(format.font),
    letterSpacing: format.letterSpacing == 0 ? null : format.letterSpacing * WordScope.scale,
    fontFeatures: format.smallCaps ? const [FontFeature.enable('smcp')] : null,
  );
}

/// When a document's font isn't on the device, a family of the same kind.
List<String>? _fallbackFonts(String? font) {
  if (font == null) return null;
  final name = font.toLowerCase();
  const serif = ['times', 'cambria', 'georgia', 'garamond', 'book antiqua', 'palatino', 'serif', 'constantia'];
  const mono = ['courier', 'consolas', 'mono', 'menlo', 'lucida console'];
  if (mono.any(name.contains)) return const ['monospace', 'Courier'];
  if (serif.any(name.contains)) return const ['serif', 'Times New Roman', 'Georgia'];
  return const ['sans-serif', 'Roboto', 'Helvetica'];
}

/// WCAG contrast ratio between two colours (1-21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

// --- Images --------------------------------------------------------------------

/// An image at its size in the document, shrunk to fit the width; a
/// placeholder (with its alt text) when it can't be shown.
class WordImageView extends StatelessWidget {
  const WordImageView(this.image, {super.key});

  final WordImage image;

  @override
  Widget build(BuildContext context) {
    final bytes = WordScope.of(context).layout.document.images[image.part];
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
      var width = image.width * WordScope.scale;
      var height = image.height * WordScope.scale;
      if (width <= 0 || height <= 0) (width, height) = (math.min(maxWidth, 200), 120);
      if (width > maxWidth) {
        height *= maxWidth / width;
        width = maxWidth;
      }
      final placeholder = Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
      return Semantics(
        image: true,
        label: image.description,
        child: bytes == null
            ? placeholder
            : Image.memory(
                bytes,
                width: width,
                height: height,
                fit: BoxFit.contain,
                cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, _, _) => placeholder,
              ),
      );
    });
  }
}

// --- Tables ----------------------------------------------------------------------

/// A table on its grid: column widths from the document, shrunk to fit the
/// screen (with a minimum per column, scrolling sideways beyond that);
/// spanned and vertically merged cells laid out over the columns and rows
/// they cover.
class WordTableView extends StatelessWidget {
  const WordTableView(this.table, {super.key});

  final WordTable table;

  static const double _minColumnWidth = 48;

  @override
  Widget build(BuildContext context) {
    final columnCount = _columnCount();
    if (columnCount == 0) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
      var widths = [
        for (var c = 0; c < columnCount; c++)
          (c < table.columnWidths.length && table.columnWidths[c] > 0 ? table.columnWidths[c] : 72) * WordScope.scale,
      ];
      final natural = widths.fold<double>(0, (a, b) => a + b);
      if (natural > available) {
        final factor = available / natural;
        widths = [for (final w in widths) math.max(_minColumnWidth, w * factor)];
      }
      final total = widths.fold<double>(0, (a, b) => a + b);
      final cells = <Widget>[];
      for (var r = 0; r < table.rows.length; r++) {
        var column = 0;
        for (final cell in table.rows[r].cells) {
          if (!cell.covered && column < columnCount) {
            final span = math.min(cell.columnSpan, columnCount - column);
            cells.add(_TableCellSlot(
              row: r,
              column: column,
              rowSpan: math.min(cell.rowSpan, table.rows.length - r),
              columnSpan: span,
              child: _WordTableCellView(
                cell,
                top: r == 0,
                left: column == 0,
                bottom: r + cell.rowSpan >= table.rows.length,
                right: column + span >= columnCount,
              ),
            ));
          }
          column += cell.columnSpan;
        }
      }
      Widget grid = _TableGrid(
        columnWidths: widths,
        rowCount: table.rows.length,
        minRowHeights: [for (final row in table.rows) (row.height ?? 0) * WordScope.scale],
        children: cells,
      );
      if (total > available) {
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid);
      }
      grid = Align(
        alignment: switch (table.alignment) {
          ParagraphAlignment.center => Alignment.center,
          ParagraphAlignment.right => AlignmentDirectional.centerEnd,
          _ => AlignmentDirectional.centerStart,
        },
        child: grid,
      );
      return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: grid);
    });
  }

  int _columnCount() {
    var widest = table.columnWidths.length;
    for (final row in table.rows) {
      final count = row.cells.fold<int>(0, (a, cell) => a + cell.columnSpan);
      if (count > widest) widest = count;
    }
    return widest;
  }
}

class _WordTableCellView extends StatelessWidget {
  const _WordTableCellView(this.cell, {required this.top, required this.left, required this.bottom, required this.right});

  final WordTableCell cell;

  /// Which sides are the table's outer edge: drawn in full there; inside,
  /// each neighbour draws half, so shared borders aren't doubled.
  final bool top;
  final bool left;
  final bool bottom;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    BorderSide side(BorderLine? line, bool outer) {
      if (line == null || line.width == 0) return BorderSide.none;
      final width = math.max(0.5, line.width * WordScope.scale);
      return BorderSide(
        width: outer ? width : width / 2,
        color: line.color == null ? scheme.outline : Color(line.color!),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cell.fill == null ? null : Color(cell.fill!),
        border: Border(
          top: side(cell.borders.top, top),
          left: side(cell.borders.left, left),
          bottom: side(cell.borders.bottom, bottom),
          right: side(cell.borders.right, right),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      alignment: switch (cell.verticalAlignment) {
        CellVerticalAlignment.top => AlignmentDirectional.topStart,
        CellVerticalAlignment.center => AlignmentDirectional.centerStart,
        CellVerticalAlignment.bottom => AlignmentDirectional.bottomStart,
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final block in cell.blocks) WordBlockView(block)],
      ),
    );
  }
}

/// Where a cell sits on the table grid.
class _TableCellSlot extends ParentDataWidget<_TableCellData> {
  const _TableCellSlot({
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
    required super.child,
  });

  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _TableCellData;
    if (data.row != row || data.column != column || data.rowSpan != rowSpan || data.columnSpan != columnSpan) {
      data
        ..row = row
        ..column = column
        ..rowSpan = rowSpan
        ..columnSpan = columnSpan;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _TableGrid;
}

class _TableCellData extends ContainerBoxParentData<RenderBox> {
  int row = 0;
  int column = 0;
  int rowSpan = 1;
  int columnSpan = 1;
}

class _TableGrid extends MultiChildRenderObjectWidget {
  const _TableGrid({required this.columnWidths, required this.rowCount, required this.minRowHeights, super.children});

  final List<double> columnWidths;
  final int rowCount;
  final List<double> minRowHeights;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTableGrid(columnWidths, rowCount, minRowHeights);

  @override
  void updateRenderObject(BuildContext context, _RenderTableGrid renderObject) {
    renderObject
      ..columnWidths = columnWidths
      ..rowCount = rowCount
      ..minRowHeights = minRowHeights;
  }
}

/// Lays cells out on fixed columns: each row is as tall as its tallest
/// single-row cell (and its minimum height); a cell spanning rows adds any
/// height it still needs to the last row it covers. Then every cell is
/// stretched to its full area, so fills and borders line up.
class _RenderTableGrid extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _TableCellData>, RenderBoxContainerDefaultsMixin<RenderBox, _TableCellData> {
  _RenderTableGrid(this._columnWidths, this._rowCount, this._minRowHeights);

  List<double> _columnWidths;
  set columnWidths(List<double> value) {
    _columnWidths = value;
    markNeedsLayout();
  }

  int _rowCount;
  set rowCount(int value) {
    _rowCount = value;
    markNeedsLayout();
  }

  List<double> _minRowHeights;
  set minRowHeights(List<double> value) {
    _minRowHeights = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TableCellData) child.parentData = _TableCellData();
  }

  double _spanWidth(_TableCellData data) {
    var width = 0.0;
    for (var c = data.column; c < data.column + data.columnSpan && c < _columnWidths.length; c++) {
      width += _columnWidths[c];
    }
    return width;
  }

  List<double> _rowHeights(double Function(RenderBox child, double width) measure) {
    final heights = [for (var r = 0; r < _rowCount; r++) r < _minRowHeights.length ? _minRowHeights[r] : 0.0];
    final spanning = <(RenderBox, _TableCellData, double)>[];
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _TableCellData;
      final height = measure(child, _spanWidth(data));
      if (data.rowSpan <= 1) {
        heights[data.row] = math.max(heights[data.row], height);
      } else {
        spanning.add((child, data, height));
      }
      child = data.nextSibling;
    }
    for (final (_, data, height) in spanning) {
      final last = math.min(data.row + data.rowSpan, _rowCount) - 1;
      var covered = 0.0;
      for (var r = data.row; r <= last; r++) {
        covered += heights[r];
      }
      if (height > covered) heights[last] += height - covered;
    }
    return heights;
  }

  @override
  void performLayout() {
    final heights = _rowHeights((child, width) {
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      return child.size.height;
    });
    final rowTops = [0.0];
    for (final h in heights) {
      rowTops.add(rowTops.last + h);
    }
    final columnLefts = [0.0];
    for (final w in _columnWidths) {
      columnLefts.add(columnLefts.last + w);
    }
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _TableCellData;
      final last = math.min(data.row + data.rowSpan, _rowCount);
      final height = rowTops[last] - rowTops[data.row];
      child.layout(BoxConstraints.tightFor(width: _spanWidth(data), height: height));
      data.offset = Offset(columnLefts[math.min(data.column, _columnWidths.length)], rowTops[data.row]);
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(columnLefts.last, rowTops.last));
  }

  double get _width => _columnWidths.fold(0.0, (a, b) => a + b);

  @override
  double computeMinIntrinsicWidth(double height) => _width;

  @override
  double computeMaxIntrinsicWidth(double height) => _width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _rowHeights((child, w) => child.getMinIntrinsicHeight(w)).fold(0.0, (a, b) => a + b);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _rowHeights((child, w) => child.getMaxIntrinsicHeight(w)).fold(0.0, (a, b) => a + b);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
