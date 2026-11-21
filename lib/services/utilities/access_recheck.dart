import 'dart:async';

/// "Check now, then again a moment later" for something the OS settles slowly (a permission granted
/// on a system page can reach the app a beat after it returns to the foreground; some phone makers
/// report the old value for a resume).
///
/// [run] checks at once, then after each of [delays] (counted from the start of [run]), and stops as
/// soon as [changed] is true or the owner is [isClosed]. Starting [run] again, or [cancel], drops the
/// checks still waiting. Tests pass short [delays] or use fake time.
class AccessRecheck {
  AccessRecheck({this.delays = defaultDelays});

  /// Roughly 0.7 s, 1.5 s and 3 s after returning.
  static const defaultDelays = [
    Duration(milliseconds: 700),
    Duration(milliseconds: 1500),
    Duration(seconds: 3),
  ];

  final List<Duration> delays;
  final _timers = <Timer>[];

  /// True while delayed checks are still waiting.
  bool get isActive => _timers.isNotEmpty;

  /// Stops any delayed check that has not run yet.
  void cancel() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Runs [check] now (the returned future completes after that first check) and again after each
  /// delay. [onSettled] runs once after the last delayed check when nothing changed and the owner is
  /// still open.
  Future<void> run({
    required Future<void> Function() check,
    required bool Function() changed,
    bool Function()? isClosed,
    void Function()? onSettled,
  }) async {
    cancel();
    bool stop() => (isClosed?.call() ?? false) || changed();
    for (var i = 0; i < delays.length; i++) {
      final last = i == delays.length - 1;
      late final Timer timer;
      timer = Timer(delays[i], () async {
        _timers.remove(timer);
        if (stop()) return;
        await check();
        if (changed()) {
          cancel();
        } else if (last && !stop()) {
          onSettled?.call();
        }
      });
      _timers.add(timer);
    }
    await check();
    if (changed()) cancel();
  }
}
