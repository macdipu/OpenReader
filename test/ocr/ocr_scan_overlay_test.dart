import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/features/ocr/presentation/ocr_scan_overlay.dart';

void main() {
  group('the beam over the document moves row by row', () {
    const height = 2800.0;
    const rowHeight = height / OcrScanOverlay.rows;

    test('it starts at the top, ends at the bottom and never moves backwards', () {
      expect(ScanPainter.headY(0, height), 0);
      expect(ScanPainter.headY(1, height), closeTo(height, 0.001));
      var last = -1.0;
      for (var i = 0; i <= 1000; i++) {
        final y = ScanPainter.headY(i / 1000, height);
        expect(y, greaterThanOrEqualTo(last));
        last = y;
      }
    });

    test('inside each row it hops to the row\'s bottom quickly and then rests there', () {
      const rowShare = 1 / OcrScanOverlay.rows;
      // A little way into row 3: still hopping, somewhere between its top and bottom.
      final hopping = ScanPainter.headY(3 * rowShare + rowShare * 0.15, height);
      expect(hopping, greaterThan(3 * rowHeight));
      expect(hopping, lessThan(4 * rowHeight));
      // Most of the way through the row it has arrived and rests on the row's bottom edge.
      final resting = ScanPainter.headY(3 * rowShare + rowShare * 0.9, height);
      expect(resting, closeTo(4 * rowHeight, 0.001));
      expect(ScanPainter.headY(3 * rowShare + rowShare * 0.6, height), closeTo(resting, 0.001));
    });

    test('it takes a few seconds to read the page, not a blink', () {
      final seconds = (OcrScanOverlay.rowTime * OcrScanOverlay.rows).inMilliseconds / 1000;
      expect(seconds, inInclusiveRange(2, 5));
    });

    test('a tag stays up long enough to read and is not left behind', () {
      expect(OcrScanOverlay.tagLife, greaterThan(const Duration(milliseconds: 1000)));
      expect(OcrScanOverlay.tagLife, lessThan(const Duration(seconds: 4)));
      expect(OcrScanOverlay.maxTags, inInclusiveRange(3, 8));
    });
  });
}
