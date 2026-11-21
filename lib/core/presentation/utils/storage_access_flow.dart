import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../services/utilities/access_recheck.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../widgets/snackbar/custom_snackbar.dart';

/// Where the All files access switch lives on common phones (onboarding and the Settings how-to).
const storageAccessVendorLines = [
  'Samsung One UI: Settings > Apps > Special access > All files access.',
  'ColorOS / realme / OnePlus: App info > Permissions > Files and media.',
  'Xiaomi / HyperOS: Settings > Apps > Manage apps > OpenReader > Permissions.',
  'vivo: Settings > Apps & permissions > Permission management.',
];

/// The text of the guidance shown when the user comes back from the OS page without access.
const storageAccessGuidance =
    'Access is still off. Choose "Allow management of all files".';

/// Shown once per attempt, after the re-check window found no access: how to finish by hand, with a
/// way to the page where access is granted. Settings > Permissions has the full steps.
void showStorageAccessGuidance(StorageAccessService access) {
  CustomSnackbar.show(
    message: storageAccessGuidance,
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

/// Completes when the app is in front again (at once if it already is, or the lifecycle is unknown, as
/// in tests). Gives up when [isClosed] turns true or after [timeout].
Future<void> waitUntilForeground({bool Function()? isClosed, Duration timeout = const Duration(minutes: 10)}) {
  final binding = WidgetsBinding.instance;
  bool inFront() {
    final state = binding.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  if (inFront()) return Future.value();
  final done = Completer<void>();
  late final _ForegroundObserver observer;
  Timer? giveUp;
  void finish() {
    if (done.isCompleted) return;
    binding.removeObserver(observer);
    giveUp?.cancel();
    done.complete();
  }

  observer = _ForegroundObserver((state) {
    if (state == AppLifecycleState.resumed || (isClosed?.call() ?? false)) finish();
  });
  binding.addObserver(observer);
  giveUp = Timer(timeout, finish);
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
/// guidance. The re-check window starts once the app is in front again, so the guidance is never shown
/// to nobody.
Future<void> requestStorageAccessFlow({
  required StorageAccessService access,
  FutureOr<void> Function()? onGranted,
  bool Function()? isClosed,
  AccessRecheck? recheck,
  void Function()? guide,
}) async {
  StorageAccessAttempt.mark();
  if (await access.requestOrOpenSettings()) {
    StorageAccessAttempt.clear();
    await onGranted?.call();
    return;
  }
  await waitUntilForeground(isClosed: isClosed);
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
