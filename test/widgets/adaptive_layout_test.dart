import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/presentation/utils/screen_utils.dart';
import 'package:openreader/core/presentation/widgets/reader/reader_safe_zone.dart';

Widget _host(WidgetTester tester, Size size, Widget child, {List<DisplayFeature> features = const []}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, displayFeatures: features),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('side navigation rule', () {
    test('phone portrait keeps the bottom bar', () {
      expect(ScreenUtils.usesSideNav(const Size(390, 844)), isFalse);
    });

    test('phone landscape gets the rail, even a narrow one', () {
      expect(ScreenUtils.usesSideNav(const Size(844, 390)), isTrue);
      expect(ScreenUtils.usesSideNav(const Size(568, 320)), isTrue);
    });

    test('tablets and desktop windows get the rail in both orientations', () {
      expect(ScreenUtils.usesSideNav(const Size(800, 1280)), isTrue);
      expect(ScreenUtils.usesSideNav(const Size(1280, 800)), isTrue);
    });

    test('a narrow, tall desktop window stays on the bottom bar', () {
      expect(ScreenUtils.usesSideNav(const Size(480, 900)), isFalse);
    });

    test('short height is anything under 500dp', () {
      expect(ScreenUtils.isShortHeight(const Size(844, 390)), isTrue);
      expect(ScreenUtils.isShortHeight(const Size(1280, 800)), isFalse);
    });
  });

  group('reader column width', () {
    test('fills a phone or a narrow window', () {
      expect(ReaderSafeZone.columnWidth(ReaderContent.page, 390), 390);
      expect(ReaderSafeZone.columnWidth(ReaderContent.page, 700), 700);
    });

    test('caps wide windows per content type', () {
      expect(ReaderSafeZone.columnWidth(ReaderContent.page, 1600), ReaderContent.page.maxWidth);
      expect(ReaderSafeZone.columnWidth(ReaderContent.text, 1600), ReaderContent.text.maxWidth);
      expect(ReaderSafeZone.columnWidth(ReaderContent.document, 1600), ReaderContent.document.maxWidth);
    });

    test('does not shrink a window that is between the breakpoint and the cap', () {
      expect(ReaderSafeZone.columnWidth(ReaderContent.page, 800), 800);
    });
  });

  group('ReaderSafeZone on screen', () {
    testWidgets('centres and caps the column on a wide window', (tester) async {
      await tester.pumpWidget(_host(
        tester,
        const Size(1600, 900),
        const ReaderSafeZone(kind: ReaderContent.text, child: SizedBox.expand(key: Key('content'))),
      ));
      expect(tester.getSize(find.byKey(const Key('content'))).width, ReaderContent.text.maxWidth);
      expect(tester.getCenter(find.byKey(const Key('content'))).dx, 800);
    });

    testWidgets('keeps the column on one side of a vertical hinge', (tester) async {
      // A Surface Duo style hinge down the middle of an 1800px wide window.
      await tester.pumpWidget(_host(
        tester,
        const Size(1800, 900),
        const ReaderSafeZone(kind: ReaderContent.page, child: SizedBox.expand(key: Key('content'))),
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(896, 0, 8, 900),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.unknown,
          ),
        ],
      ));
      final box = tester.getRect(find.byKey(const Key('content')));
      expect(box.right, lessThanOrEqualTo(896), reason: 'nothing may sit under or past the hinge');
    });

    testWidgets('puts the column in the top half in tabletop posture', (tester) async {
      // A flip phone half open: horizontal fold across the middle.
      await tester.pumpWidget(_host(
        tester,
        const Size(700, 1000),
        const ReaderSafeZone(kind: ReaderContent.page, child: SizedBox.expand(key: Key('content'))),
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 496, 700, 8),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      ));
      final box = tester.getRect(find.byKey(const Key('content')));
      expect(box.bottom, lessThanOrEqualTo(496), reason: 'the bottom half is left for the toolbar');
    });

    testWidgets('ignores a flat fold (an unfolded Fold is one big screen)', (tester) async {
      await tester.pumpWidget(_host(
        tester,
        const Size(900, 900),
        const ReaderSafeZone(kind: ReaderContent.page, child: SizedBox.expand(key: Key('content'))),
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(448, 0, 4, 900),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      ));
      expect(tester.getSize(find.byKey(const Key('content'))).width, 900);
    });
  });
}
