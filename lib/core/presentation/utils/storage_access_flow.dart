import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../services/utilities/access_recheck.dart';
import '../../../services/utilities/storage_access_service.dart';
import 'storage_access_help.dart';
import '../widgets/snackbar/custom_snackbar.dart';

/// The text of the guidance shown when the user comes back from the OS page without access.
const storageAccessGuidance =
    'Access is still off. Choose "Allow management of all files".';

/// Quotes this phone's own switch wording once the brand is known (cached by an earlier lookup);
/// before that, the brand-neutral [storageAccessGuidance].
String _guidanceFor(StorageAccessService access) {
  try {
    final brand = access.cachedBrand;
    if (brand != null) return 'Access is still off. Choose "${StorageAccessHelp.switchLabelFor(brand)}".';
  } catch (_) {}
  return storageAccessGuidance;
}

/// Shown once per attempt, after the re-check window found no access: how to finish by hand, with a
/// way to the page where access is granted. Settings > Permissions has the full steps.
void showStorageAccessGuidance(StorageAccessService access) {
  CustomSnackbar.show(
    message: _guidanceFor(access),
    type: SnackbarType.warning,
    duration: const Duration(seconds: 8),
    actionLabel: 'Open settings',
    // The page where the switch is (All files access), not the general app-info page.
    onAction: () => unawaited(access.openAllFilesAccessSettings()),
  );
}

/// Remembers that the user just went to the OS page to grant access, so the "still off" guidance can
/// also be shown when they come back by a route that never finishes the request (on some phones the
/// toolbar arrow of the system page lands on the app-info page, and the request returns while the app
/// is still behind it).
class StorageAccessAttempt {
  StorageAccessAttempt._();

  static DateTime? _at;

  static void mark([DateTime? now]) => _at = now ?? DateTime.now();

  static void clear() => _at = null;

  /// True once for a recent attempt (and forgets it), so two paths to the same guidance show it once.
  static bool takeRecent({Duration within = const Duration(minutes: 5), DateTime? now}) {
    final at = _at;
    _at = null;
    if (at == null) return false;
    return (now ?? DateTime.now()).difference(at) <= within;
  }
}

bool _appInFront() {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// Notes whether the app left the foreground while it runs (the OS permission page opened over it).
class _LeftAppWatch with WidgetsBindingObserver {
  bool left = false;

  void start() => WidgetsBinding.instance.addObserver(this);

  /// Stops watching; true if the app was away at any point.
  bool stop() {
    WidgetsBinding.instance.removeObserver(this);
    return left;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) left = true;
  }
}

/// Completes when the app is in front again *and stays there* for [settle] (at once if it already is,
/// or the lifecycle is unknown, as in tests). Some system pages hand control back to the app for a
/// moment and then cover it again (One UI's toolbar arrow on the All files access page goes on to
/// App info), so the first "resumed" is not enough: the wait restarts if the app leaves again before
/// [settle] has passed. Gives up when [isClosed] turns true or after [timeout].
Future<void> waitUntilForeground({
  bool Function()? isClosed,
  Duration timeout = const Duration(minutes: 10),
  Duration settle = const Duration(milliseconds: 800),
}) {
  final binding = WidgetsBinding.instance;
  bool inFront() {
    final state = binding.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  if (inFront() && settle == Duration.zero) return Future.value();
  final done = Completer<void>();
  late final _ForegroundObserver observer;
  Timer? giveUp;
  Timer? settling;
  void finish() {
    if (done.isCompleted) return;
    binding.removeObserver(observer);
    giveUp?.cancel();
    settling?.cancel();
    done.complete();
  }

  // The app is in front now (or came back): finish once it has stayed for [settle].
  void startSettling() {
    settling?.cancel();
    settling = Timer(settle, () {
      if (inFront() || (isClosed?.call() ?? false)) finish();
    });
  }

  observer = _ForegroundObserver((state) {
    if (isClosed?.call() ?? false) return finish();
    if (state == AppLifecycleState.resumed) {
      startSettling();
    } else {
      settling?.cancel();
    }
  });
  binding.addObserver(observer);
  giveUp = Timer(timeout, finish);
  if (inFront()) startSettling();
  return done.future;
}

class _ForegroundObserver with WidgetsBindingObserver {
  _ForegroundObserver(this.onState);
  final void Function(AppLifecycleState state) onState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onState(state);
}

/// "Grant Access" from Home, Browse and the access snackbars: asks (opening the OS page where that is
/// the way), and when the user comes back without access keeps checking for a few seconds in case the
/// grant is late. [onGranted] runs once access shows up. If it never does, [guide] (guidance with
/// "Open settings") runs once; by default the shared snackbar. A grant on the first answer shows no
/// guidance. The re-check window starts once the app is in front again and has stayed there, so the
/// guidance is never shown to nobody.
Future<void> requestStorageAccessFlow({
  required StorageAccessService access,
  FutureOr<void> Function()? onGranted,
  bool Function()? isClosed,
  AccessRecheck? recheck,
  void Function()? guide,
}) async {
  StorageAccessAttempt.mark();
  final watch = _LeftAppWatch()..start();
  final granted0 = await access.requestOrOpenSettings();
  final leftApp = watch.stop();
  if (granted0) {
    StorageAccessAttempt.clear();
    await onGranted?.call();
    return;
  }
  // The app was behind the OS page (or still is): time the re-check window from when it is really
  // back in front, so the guidance is not shown to nobody.
  if (leftApp || !_appInFront()) await waitUntilForeground(isClosed: isClosed);
  if (isClosed?.call() ?? false) return;
  var granted = false;
  await (recheck ?? AccessRecheck()).run(
    check: () async {
      if (granted || !await access.hasAccess()) return;
      granted = true;
      StorageAccessAttempt.clear();
      await onGranted?.call();
    },
    changed: () => granted,
    isClosed: isClosed,
    onSettled: () {
      if (!StorageAccessAttempt.takeRecent()) return;
      (guide ?? () => showStorageAccessGuidance(access))();
    },
  );
}
