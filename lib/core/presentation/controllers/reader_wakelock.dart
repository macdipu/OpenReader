import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/repositories/app_settings_repository_impl.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// Turns the platform's screen wakelock on and off. Tests inject a fake instead of the plugin.
abstract class WakelockAdapter {
  Future<void> enable();
  Future<void> disable();
}

/// [WakelockAdapter] backed by `wakelock_plus`.
class WakelockPlusAdapter implements WakelockAdapter {
  const WakelockPlusAdapter();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

/// "Keep screen awake while reading" (ST-16): the screen stays on only while the switch is on, a
/// reader is visible and the app is in the foreground. Every reader screen reports itself through
/// [ReaderKeepAwake]; Settings writes [keepAwake], the app loads it once at start.
///
/// A wakelock is a convenience: a platform without one, or a call that fails, is ignored.
class ReaderWakelock {
  ReaderWakelock._();

  static final keepAwake = false.obs..listen((_) => _sync());

  /// Where the lock is taken; replace it in tests.
  static WakelockAdapter adapter = const WakelockPlusAdapter();

  static final _visibleReaders = <Object>{};
  static bool _appActive = true;
  static bool _held = false;
  static _LifecycleObserver? _observer;

  /// Whether the lock is wanted right now (the last state sent to [adapter]).
  static bool get isHeld => _held;

  /// Reads the saved choice. An unreadable store leaves it off.
  static Future<void> load([AppSettingsRepository? repository]) async {
    try {
      keepAwake.value = await (repository ?? AppSettingsRepositoryImpl()).getKeepScreenAwake();
    } catch (_) {}
  }

  /// A reader with [token] is on screen.
  static void readerShown(Object token) {
    if (_observer == null) {
      _observer = _LifecycleObserver();
      WidgetsBinding.instance.addObserver(_observer!);
    }
    if (_visibleReaders.add(token)) _sync();
  }

  /// The reader with [token] is hidden or closed.
  static void readerHidden(Object token) {
    if (_visibleReaders.remove(token)) _sync();
  }

  static void _lifecycleChanged(AppLifecycleState state) {
    // Inactive is still on screen (a system sheet over the app); paused, hidden or detached is not.
    final active = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (active == _appActive) return;
    _appActive = active;
    _sync();
  }

  static void _sync() {
    final want = keepAwake.value && _visibleReaders.isNotEmpty && _appActive;
    if (want == _held) return;
    _held = want;
    try {
      unawaited((want ? adapter.enable() : adapter.disable()).catchError((_) {}));
    } catch (_) {
      // Unsupported platform or plugin missing: no lock, reading still works.
    }
  }

  /// Back to the start state, for tests.
  @visibleForTesting
  static void reset({WakelockAdapter? adapter}) {
    _visibleReaders.clear();
    _appActive = true;
    _held = false;
    keepAwake.value = false;
    ReaderWakelock.adapter = adapter ?? const WakelockPlusAdapter();
  }

  @visibleForTesting
  static void debugLifecycleChanged(AppLifecycleState state) => _lifecycleChanged(state);
}

class _LifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => ReaderWakelock._lifecycleChanged(state);
}

/// Marks its subtree as a reader screen for [ReaderWakelock]: shown while mounted and ticking (a
/// covered route, a background workspace tab and an offstage shell page don't tick), hidden when
/// it stops ticking or is removed.
class ReaderKeepAwake extends StatefulWidget {
  final Widget child;
  const ReaderKeepAwake({super.key, required this.child});

  @override
  State<ReaderKeepAwake> createState() => _ReaderKeepAwakeState();
}

class _ReaderKeepAwakeState extends State<ReaderKeepAwake> {
  final _token = Object();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled) {
      ReaderWakelock.readerShown(_token);
    } else {
      ReaderWakelock.readerHidden(_token);
    }
  }

  @override
  void dispose() {
    ReaderWakelock.readerHidden(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
