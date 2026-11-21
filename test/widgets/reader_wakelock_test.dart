import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/presentation/controllers/reader_wakelock.dart';
import 'package:openreader/core/presentation/widgets/reader/reader_night_mode_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openreader/core/data/repositories/app_settings_repository_impl.dart';

/// Records what the wakelock was told; never calls the plugin.
class FakeWakelock implements WakelockAdapter {
  final calls = <bool>[];
  bool get enabled => calls.isNotEmpty && calls.last;

  @override
  Future<void> enable() async => calls.add(true);

  @override
  Future<void> disable() async => calls.add(false);
}

class ThrowingWakelock implements WakelockAdapter {
  @override
  Future<void> enable() => throw UnsupportedError('no wakelock here');

  @override
  Future<void> disable() async => throw UnsupportedError('no wakelock here');
}

/// The screen-level wrapper every reader view has.
Widget reader() => const ReaderNightModeView(enabled: false, child: Text('reader'));

void main() {
  late FakeWakelock wakelock;
  final navigatorKey = GlobalKey<NavigatorState>();

  setUp(() {
    wakelock = FakeWakelock();
    ReaderWakelock.reset(adapter: wakelock);
  });
  tearDown(ReaderWakelock.reset);

  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const Text('home')));
  }

  Future<void> openReader(WidgetTester tester) async {
    navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: reader())));
    await tester.pumpAndSettle();
  }

  Future<void> closeTop(WidgetTester tester) async {
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  }

  testWidgets('default off: an open reader does not keep the screen awake', (tester) async {
    expect(ReaderWakelock.keepAwake.value, isFalse);
    await openHome(tester);
    await openReader(tester);
    expect(wakelock.calls, isEmpty);
    expect(ReaderWakelock.isHeld, isFalse);
  });

  testWidgets('on + reader open => enabled; reader closed => disabled', (tester) async {
    ReaderWakelock.keepAwake.value = true;
    await openHome(tester);
    expect(wakelock.calls, isEmpty, reason: 'no reader yet');
    await openReader(tester);
    expect(wakelock.enabled, isTrue);
    await closeTop(tester);
    expect(wakelock.calls, [true, false]);
  });

  testWidgets('switch turned on while a reader is open => enabled at once', (tester) async {
    await openHome(tester);
    await openReader(tester);
    ReaderWakelock.keepAwake.value = true;
    expect(wakelock.calls, [true]);
  });

  testWidgets('switch turned off while a reader is open => disabled', (tester) async {
    ReaderWakelock.keepAwake.value = true;
    await openHome(tester);
    await openReader(tester);
    ReaderWakelock.keepAwake.value = false;
    expect(wakelock.calls, [true, false]);
  });

  testWidgets('app paused => disabled; resumed with the reader still open => enabled again', (tester) async {
    ReaderWakelock.keepAwake.value = true;
    await openHome(tester);
    await openReader(tester);
    ReaderWakelock.debugLifecycleChanged(AppLifecycleState.inactive);
    expect(wakelock.calls, [true], reason: 'inactive is still on screen');
    ReaderWakelock.debugLifecycleChanged(AppLifecycleState.hidden);
    ReaderWakelock.debugLifecycleChanged(AppLifecycleState.paused);
    expect(wakelock.calls, [true, false]);
    ReaderWakelock.debugLifecycleChanged(AppLifecycleState.resumed);
    expect(wakelock.calls, [true, false, true]);
  });

  testWidgets('a page pushed over the reader releases it; back to the reader takes it again', (tester) async {
    ReaderWakelock.keepAwake.value = true;
    await openHome(tester);
    await openReader(tester);
    navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('info'))));
    await tester.pumpAndSettle();
    expect(wakelock.enabled, isFalse);
    await closeTop(tester);
    expect(wakelock.enabled, isTrue);
  });

  testWidgets('a background workspace tab (offstage, not ticking) does not count', (tester) async {
    ReaderWakelock.keepAwake.value = true;
    final visible = ValueNotifier(false);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, shown, child) => Offstage(offstage: !shown, child: TickerMode(enabled: shown, child: reader())),
      ),
    ));
    expect(wakelock.calls, isEmpty);
    visible.value = true;
    await tester.pump();
    expect(wakelock.enabled, isTrue);
    visible.value = false;
    await tester.pump();
    expect(wakelock.enabled, isFalse);
  });

  testWidgets('two readers on screen: the lock stays until the last one goes', (tester) async {
    ReaderWakelock.keepAwake.value = true;
    final count = ValueNotifier(2);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: count,
        builder: (context, n, child) => Column(children: [for (var i = 0; i < n; i++) SizedBox(height: 50, child: reader())]),
      ),
    ));
    expect(wakelock.calls, [true]);
    count.value = 1;
    await tester.pump();
    expect(wakelock.calls, [true]);
    count.value = 0;
    await tester.pump();
    expect(wakelock.calls, [true, false]);
  });

  testWidgets('a platform without a wakelock never throws into the UI', (tester) async {
    ReaderWakelock.reset(adapter: ThrowingWakelock());
    ReaderWakelock.keepAwake.value = true;
    await openHome(tester);
    await openReader(tester);
    await closeTop(tester);
    expect(tester.takeException(), isNull);
  });

  test('load reads the saved choice; default off', () async {
    SharedPreferences.setMockInitialValues({});
    await ReaderWakelock.load(AppSettingsRepositoryImpl());
    expect(ReaderWakelock.keepAwake.value, isFalse);
    SharedPreferences.setMockInitialValues({'app_settings:keep_screen_awake': true});
    await ReaderWakelock.load(AppSettingsRepositoryImpl());
    expect(ReaderWakelock.keepAwake.value, isTrue);
  });

  test('every reader screen goes through the shared wrapper', () {
    for (final view in [
      'pdf_reader/presentation/pdf_reader_view.dart',
      'word_reader/presentation/word_reader_view.dart',
      'excel_reader/presentation/excel_reader_view.dart',
      'powerpoint_reader/presentation/powerpoint_reader_view.dart',
      'csv_reader/presentation/csv_reader_view.dart',
      'text_reader/presentation/text_reader_view.dart',
    ]) {
      final source = File('lib/features/$view').readAsStringSync();
      expect(source, contains('// The whole reader, bars included, goes dark at night.'), reason: view);
      expect(source, contains('ReaderNightModeView('), reason: view);
    }
  });
}
