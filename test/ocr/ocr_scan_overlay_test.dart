import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/ocr/presentation/ocr_scan_overlay.dart';

void main() {
  group('the scan head painter', () {
    void paintAt(double fraction, {Size size = const Size(400, 600)}) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      ScanPainter(fraction, color: Colors.blue).paint(canvas, size);
      recorder.endRecording().dispose();
    }

    test('paints at the top, the middle and the bottom, outside the page and on a zero-sized page, without failing', () {
      for (final f in [0.0, 0.01, 0.5, 0.99, 1.0, -0.5, 2.0]) {
        paintAt(f);
      }
      paintAt(0.5, size: Size.zero);
      paintAt(0.5, size: const Size(400, 0));
    });

    test('it repaints when the head moves or the colour changes, and not otherwise', () {
      final a = ScanPainter(0.3, color: Colors.blue);
      expect(a.shouldRepaint(ScanPainter(0.3, color: Colors.blue)), isFalse);
      expect(a.shouldRepaint(ScanPainter(0.4, color: Colors.blue)), isTrue);
      expect(a.shouldRepaint(ScanPainter(0.3, color: Colors.red)), isTrue);
    });
  });

  test('a long page is played back in a handful of hops, so it takes seconds, not a minute', () {
    expect(OcrScanOverlay.backlogHops, inInclusiveRange(4, 12));
  });
}
