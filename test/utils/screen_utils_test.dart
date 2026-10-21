import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/presentation/utils/screen_utils.dart';

void main() {
  test('sizeForWidth maps widths onto the window size classes', () {
    expect(ScreenUtils.sizeForWidth(360), ScreenSize.compact);
    expect(ScreenUtils.sizeForWidth(599.9), ScreenSize.compact);
    expect(ScreenUtils.sizeForWidth(600), ScreenSize.medium);
    expect(ScreenUtils.sizeForWidth(1023.9), ScreenSize.medium);
    expect(ScreenUtils.sizeForWidth(1024), ScreenSize.expanded);
    expect(ScreenUtils.sizeForWidth(2560), ScreenSize.expanded);
  });

  testWidgets('ContentConstraint caps width on a wide window only', (tester) async {
    Future<double> widthAt(double window) async {
      tester.view.physicalSize = Size(window, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentConstraint(maxWidth: 500, child: SizedBox.expand(key: Key('c'))),
      ));
      return tester.getSize(find.byKey(const Key('c'))).width;
    }

    expect(await widthAt(1400), 500);
    expect(await widthAt(360), 360);
  });
}
