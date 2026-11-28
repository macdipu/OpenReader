import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/presentation/widgets/app_shortcuts.dart';
import 'package:openreader/core/presentation/widgets/reader/reader_menu_extras.dart';

void main() {
  Future<List<String>> press(
    WidgetTester tester,
    List<LogicalKeyboardKey> keys, {
    bool wired = true,
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: AppShortcuts(
        onZoomIn: wired ? () => calls.add('in') : null,
        onZoomOut: wired ? () => calls.add('out') : null,
        onZoomReset: wired ? () => calls.add('reset') : null,
        onGoTo: wired ? () => calls.add('goto') : null,
        onPreviousPage: wired ? () => calls.add('prev') : null,
        onNextPage: wired ? () => calls.add('next') : null,
        onFirstPage: wired ? () => calls.add('first') : null,
        onLastPage: wired ? () => calls.add('last') : null,
        onFullscreen: wired ? () => calls.add('full') : null,
        onPrint: wired ? () => calls.add('print') : null,
        child: const Scaffold(body: SizedBox()),
      ),
    ));
    await tester.pump();
    for (final key in keys) {
      await tester.sendKeyEvent(key);
    }
    return calls;
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey modifier, LogicalKeyboardKey key,
      {bool shift = false}) async {
    await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
  }

  group('reader shortcuts', () {
    testWidgets('Cmd and Ctrl zoom in (with or without Shift for +), out, and back to normal', (tester) async {
      final calls = await press(tester, const []);
      for (final modifier in [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.controlLeft]) {
        await chord(tester, modifier, LogicalKeyboardKey.equal);
        await chord(tester, modifier, LogicalKeyboardKey.equal, shift: true);
        await chord(tester, modifier, LogicalKeyboardKey.minus);
        await chord(tester, modifier, LogicalKeyboardKey.digit0);
      }
      expect(calls, ['in', 'in', 'out', 'reset', 'in', 'in', 'out', 'reset']);
    });

    testWidgets('Ctrl+G goes to; Cmd+G is left for find next', (tester) async {
      final calls = await press(tester, const []);
      await chord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyG);
      await chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyG);
      expect(calls, ['goto']);
    });

    testWidgets('page keys and full screen', (tester) async {
      final calls = await press(tester, [
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.f11,
      ]);
      expect(calls, ['prev', 'next', 'first', 'last', 'full']);
    });

    testWidgets('Cmd and Ctrl+P print', (tester) async {
      final calls = await press(tester, const []);
      await chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyP);
      await chord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyP);
      expect(calls, ['print', 'print']);
    });

    testWidgets('a reader that passes no action leaves the key alone', (tester) async {
      final calls = await press(tester, [LogicalKeyboardKey.pageDown, LogicalKeyboardKey.f11], wired: false);
      expect(calls, isEmpty);
    });

    test('every shortcut is listed for Settings', () {
      final labels = appShortcutReference.map((s) => s.label(macOS: true)).toList();
      expect(labels, containsAll(['Cmd+0', 'Ctrl+G', 'F11']));
    });
  });

  group('show in folder', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is worded for the platform, and desktop only', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(showInFolderAvailable, isTrue);
      expect(showInFolderLabel, 'Show in Finder');
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(showInFolderLabel, 'Show in Explorer');
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(showInFolderLabel, 'Show in folder');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(showInFolderAvailable, isFalse);
    });
  });
}
