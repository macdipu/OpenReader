// Dev tool, not a test: renders every OpenReader icon asset from ONE master
// drawing (the painter below) through Flutter's own rendering pipeline, so
// no SVG rasterizer or ImageMagick is needed and every size matches.
//
// The mark: the OpenReader open book with five document tabs rising from its
// spine, one per format family, each with a tiny hint of its content: PDF
// (lines, red), Word (paragraph, blue), Excel (grid, green), PowerPoint (slide,
// amber) and Markdown/text (code chevrons, teal). No text, so it holds up at
// launcher sizes. assets/icon/icon.svg is the same drawing as vector.
//
// Run: flutter test tool/generate_app_icon.dart
//
// Writes (all derived from the same painter):
//   assets/icon/icon.png             1024, full-bleed square: iOS source, fallback
//   assets/icon/icon_rounded.png     1024, rounded square on transparent: macOS,
//                                    Windows, web, Linux, docs
//   assets/icon/icon_foreground.png  1024, transparent: Android adaptive foreground
//   assets/icon/icon_background.png  1024, background gradient: adaptive background
//   assets/icon/icon_monochrome.png  1024, white silhouette: Android 13 themed icon
//   docs/icon.png                    512, rounded: README and website
//   fastlane/.../images/icon.png     512, full-bleed: Google Play listing icon
//   fastlane/.../images/featureGraphic.png  1024x500 Play feature graphic
//
// Then regenerate platform assets:
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _playImages = 'fastlane/metadata/android/en-US/images';

void main() {
  testWidgets('generate icon assets', (tester) async {
    await _write(tester, 'assets/icon/icon.png', 1024, const _Icon(shape: _Shape.fullBleed));
    await _write(tester, 'assets/icon/icon_rounded.png', 1024, const _Icon(shape: _Shape.rounded));
    await _write(tester, 'assets/icon/icon_foreground.png', 1024, const _Icon(shape: _Shape.none, markScale: _adaptiveScale));
    await _write(tester, 'assets/icon/icon_background.png', 1024, const _Icon(shape: _Shape.fullBleed, mark: false));
    await _write(tester, 'assets/icon/icon_monochrome.png', 1024, const _Icon(shape: _Shape.none, markScale: _adaptiveScale, mono: true));
    await _write(tester, 'docs/icon.png', 512, const _Icon(shape: _Shape.rounded));
    await _write(tester, '$_playImages/icon.png', 512, const _Icon(shape: _Shape.fullBleed));
  });

  testWidgets('generate Play feature graphic', (tester) async {
    // Real file I/O must run outside the test's fake-async zone.
    await tester.runAsync(() async {
      final bytes = await File('assets/fonts/Inter.ttf').readAsBytes();
      final inter = FontLoader('Inter')..addFont(Future.value(ByteData.sublistView(bytes)));
      await inter.load();
    });
    await _write(tester, '$_playImages/featureGraphic.png', 1024, const _FeatureGraphic(), height: 500);
  });
}

/// Scale of the mark inside Android's adaptive-icon layers. flutter_launcher_icons
/// insets these layers by 16%, and launchers mask the result to a circle of
/// about 61% of the full layer; 1.15 fills that circle without clipping the
/// outer tabs or page corners.
const _adaptiveScale = 1.15;

Future<void> _write(WidgetTester tester, String path, int width, Widget widget, {int? height}) async {
  final h = height ?? width;
  final key = GlobalKey();
  tester.view.physicalSize = Size(width.toDouble(), h.toDouble());
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(width: width.toDouble(), height: h.toDouble(), child: widget),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
  });
}

enum _Shape { fullBleed, rounded, none }

class _Icon extends StatelessWidget {
  const _Icon({required this.shape, this.markScale = 1, this.mono = false, this.mark = true});

  final _Shape shape;
  final double markScale;
  final bool mono;
  final bool mark;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _IconPainter(shape: shape, markScale: markScale, mono: mono, mark: mark));
}

/// Everything is drawn in a 1024 x 1024 design space (the units of
/// assets/icon/icon.svg) and scaled to the canvas.
class _IconPainter extends CustomPainter {
  _IconPainter({required this.shape, required this.markScale, required this.mono, required this.mark});

  final _Shape shape;
  final double markScale;
  final bool mono;
  final bool mark;

  static const _radius = 232.0;

  /// The mark's vertical centre in design units (tabs start at 180, the book
  /// ends at 832).
  static const _markCenterY = 506.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024);
    const full = Rect.fromLTWH(0, 0, 1024, 1024);

    if (shape != _Shape.none) {
      final bg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1120), Color(0xFF182234), Color(0xFF080C14)],
          stops: [0, 0.5, 1],
        ).createShader(full);
      if (shape == _Shape.rounded) {
        final rrect = RRect.fromRectAndRadius(full, const Radius.circular(_radius));
        canvas.drawRRect(rrect, bg);
        canvas.drawRRect(
          rrect.deflate(2.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x38FFFFFF), Color(0x0AFFFFFF), Color(0x66000000)],
              stops: [0, 0.3, 1],
            ).createShader(full),
        );
        canvas.clipRRect(rrect);
      } else {
        canvas.drawRect(full, bg);
      }
    }

    if (mark) {
      canvas.save();
      canvas.translate(512, 512);
      canvas.scale(markScale);
      canvas.translate(-512, -_markCenterY);
      if (!mono) _glow(canvas);
      if (mono) {
        _paintMono(canvas);
      } else {
        _paintMark(canvas);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  void _glow(Canvas canvas) {
    const center = Offset(512, 520);
    canvas.drawCircle(
      center,
      400,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x3338BDF8), Color(0x120284C7), Color(0x000284C7)],
          stops: [0, 0.65, 1],
        ).createShader(Rect.fromCircle(center: center, radius: 400)),
    );
  }

  // Format tabs, left to right: where they sit, size, colours, and the symbol
  // that hints at the format (document lines, text, grid, slide, code).
  static const _tabs = [
    _Tab(274, 210, 190, Color(0xFFFF5252), Color(0xFFD32F2F), _Symbol.pdf),
    _Tab(372, 190, 210, Color(0xFF448AFF), Color(0xFF1565C0), _Symbol.word),
    _Tab(470, 180, 220, Color(0xFF00E676), Color(0xFF2E7D32), _Symbol.excel),
    _Tab(568, 190, 210, Color(0xFFFFAB40), Color(0xFFEF6C00), _Symbol.slides),
    _Tab(666, 210, 190, Color(0xFF1DE9B6), Color(0xFF00838F), _Symbol.code),
  ];
  static const _tabWidth = 84.0;

  static final Path _leftPage = Path()
    ..moveTo(220, 355)
    ..cubicTo(220, 325, 245, 308, 275, 316)
    ..lineTo(476, 368)
    ..cubicTo(496, 373, 508, 390, 508, 410)
    ..lineTo(508, 795)
    ..cubicTo(508, 818, 488, 832, 466, 826)
    ..lineTo(265, 774)
    ..cubicTo(238, 767, 220, 743, 220, 715)
    ..close();

  static final Path _rightPage = Path()
    ..moveTo(804, 355)
    ..cubicTo(804, 325, 779, 308, 749, 316)
    ..lineTo(548, 368)
    ..cubicTo(528, 373, 516, 390, 516, 410)
    ..lineTo(516, 795)
    ..cubicTo(516, 818, 536, 832, 558, 826)
    ..lineTo(759, 774)
    ..cubicTo(786, 767, 804, 743, 804, 715)
    ..close();

  static const _pageLines = [
    Rect.fromLTWH(275, 425, 130, 14),
    Rect.fromLTWH(275, 460, 175, 12),
    Rect.fromLTWH(275, 490, 160, 12),
    Rect.fromLTWH(275, 520, 110, 12),
  ];

  RRect _tabRect(_Tab tab) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(tab.x, tab.y, _tabWidth, tab.height), const Radius.circular(22));

  void _paintMark(Canvas canvas) {
    // Soft shadow under the whole group.
    final shadow = Paint()
      ..color = const Color(0x8C000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.save();
    canvas.translate(0, 24);
    canvas.drawPath(_leftPage, shadow);
    canvas.drawPath(_rightPage, shadow);
    canvas.restore();

    for (final tab in _tabs) {
      canvas.drawRRect(
        _tabRect(tab),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tab.top, tab.bottom],
          ).createShader(Rect.fromLTWH(tab.x, tab.y, _tabWidth, tab.height)),
      );
      _symbol(canvas, tab, Paint()..color = Colors.white);
    }

    // Spine behind the pages.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(488, 340, 48, 470), const Radius.circular(16)),
      Paint()..color = const Color(0xFF0D3B66),
    );
    canvas.drawPath(
      _leftPage,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEEF2F6)],
        ).createShader(_leftPage.getBounds()),
    );
    final lines = Paint()..color = const Color(0x381E293B);
    for (final line in _pageLines) {
      canvas.drawRRect(RRect.fromRectAndRadius(line, Radius.circular(line.height / 2)), lines);
    }
    canvas.drawPath(
      _rightPage,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E90FF), Color(0xFF0052CC)],
        ).createShader(_rightPage.getBounds()),
    );
    canvas.drawLine(
      const Offset(512, 382),
      const Offset(512, 812),
      Paint()
        ..color = const Color(0x59082544)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Android 13 themed icon: one-colour silhouette (the launcher tints the
  /// alpha). Tab symbols and page lines are cut out; a gap separates the pages
  /// from the tabs.
  void _paintMono(Canvas canvas) {
    final white = Paint()..color = Colors.white;
    final cut = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 1024, 1024), Paint());
    for (final tab in _tabs) {
      canvas.drawRRect(_tabRect(tab), white);
      _symbol(canvas, tab, cut);
    }
    final gap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.clear;
    canvas.drawPath(_leftPage, gap);
    canvas.drawPath(_rightPage, gap);
    canvas.drawPath(_leftPage, white);
    canvas.drawPath(_rightPage, white);
    for (final line in _pageLines) {
      canvas.drawRRect(RRect.fromRectAndRadius(line, Radius.circular(line.height / 2)), cut);
    }
    canvas.restore();
  }

  void _symbol(Canvas canvas, _Tab tab, Paint paint) {
    canvas.save();
    canvas.translate(tab.x, tab.y);
    RRect bar(double x, double y, double w, double h) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(h / 2));
    RRect cell(double x, double y) => RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 17, 14), const Radius.circular(3));
    Paint stroked(double width) => Paint()
      ..blendMode = paint.blendMode
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (tab.symbol) {
      case _Symbol.pdf:
        canvas.drawRRect(bar(22, 28, 40, 8), paint);
        canvas.drawRRect(bar(22, 44, 26, 8), paint);
      case _Symbol.word:
        canvas.drawRRect(bar(20, 26, 44, 7), paint);
        canvas.drawRRect(bar(20, 40, 44, 7), paint);
        canvas.drawRRect(bar(20, 54, 30, 7), paint);
      case _Symbol.excel:
        canvas.drawRRect(cell(22, 26), paint);
        canvas.drawRRect(cell(45, 26), paint);
        canvas.drawRRect(cell(22, 46), paint);
        canvas.drawRRect(cell(45, 46), paint);
      case _Symbol.slides:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(20, 26, 44, 32), const Radius.circular(6)),
          stroked(6),
        );
        canvas.drawCircle(const Offset(42, 42), 5, paint);
      case _Symbol.code:
        canvas.drawPath(
          Path()
            ..moveTo(35, 30)
            ..lineTo(24, 41)
            ..lineTo(35, 52)
            ..moveTo(49, 30)
            ..lineTo(60, 41)
            ..lineTo(49, 52),
          stroked(6.5),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) => false;
}

enum _Symbol { pdf, word, excel, slides, code }

class _Tab {
  const _Tab(this.x, this.y, this.height, this.top, this.bottom, this.symbol);

  final double x;
  final double y;
  final double height;
  final Color top;
  final Color bottom;
  final _Symbol symbol;
}

/// Play Store feature graphic: the rounded icon, the name and the formats.
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1013),
      child: Stack(
        children: [
          Positioned(
            left: -60,
            top: 20,
            child: Container(
              width: 520,
              height: 460,
              decoration: const BoxDecoration(
                gradient: RadialGradient(colors: [Color(0x330284C7), Color(0x000284C7)]),
              ),
            ),
          ),
          const Positioned(left: 80, top: 120, width: 260, height: 260, child: const _Icon(shape: _Shape.rounded)),
          const Positioned(
            left: 400,
            top: 150,
            child: Text(
              'OpenReader',
              style: TextStyle(fontFamily: 'Inter', fontSize: 72, fontWeight: FontWeight.w300, color: Color(0xFFF1F5F9), letterSpacing: -1),
            ),
          ),
          const Positioned(
            left: 402,
            top: 252,
            child: Text(
              'PDF, Word, Excel, PowerPoint,\nMarkdown & text documents\nin one reader',
              style: TextStyle(fontFamily: 'Inter', fontSize: 31, height: 1.35, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
