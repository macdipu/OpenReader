import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/presentation/controllers/reader_rotation.dart';
import 'package:openreader/core/presentation/widgets/reader/reader_rotated.dart';

class _Rotating extends GetxController with ReaderRotation {}

void main() {
  test('turns clockwise and anticlockwise, and four turns come back', () {
    final c = _Rotating();
    expect(c.quarterTurns.value, 0);
    c.rotateClockwise();
    expect(c.quarterTurns.value, 1);
    c.rotateCounterclockwise();
    c.rotateCounterclockwise();
    expect(c.quarterTurns.value, 3, reason: 'anticlockwise from upright is three quarter turns clockwise');
    c.rotateClockwise();
    expect(c.quarterTurns.value, 0);
    for (var i = 0; i < 4; i++) {
      c.rotateClockwise();
    }
    expect(c.quarterTurns.value, 0);
  });

  testWidgets('ReaderRotated turns the body and swaps its shape, keeping the same widget state', (tester) async {
    final c = _Rotating();
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 100,
          child: ReaderRotated(controller: c, child: SizedBox.expand(key: key)),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(key)), const Size(300, 100));
    final element = tester.element(find.byKey(key));

    c.rotateClockwise();
    await tester.pump();
    expect(tester.getSize(find.byKey(key)), const Size(100, 300), reason: 'the body fills the turned box');
    expect(identical(tester.element(find.byKey(key)), element), isTrue, reason: 'the document is not rebuilt');

    c.rotateClockwise();
    await tester.pump();
    expect(tester.getSize(find.byKey(key)), const Size(300, 100));
  });
}
