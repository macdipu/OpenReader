import 'dart:async';

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
    'File access is still off. Choose "Allow management of all files" for OpenReader, not "media only".';

/// Shown once per attempt, after the re-check window found no access: how to finish by hand, with a
/// way to the app's settings. Settings > Permissions has the full steps.
void showStorageAccessGuidance(StorageAccessService access) {
  CustomSnackbar.show(
    message: storageAccessGuidance,
    type: SnackbarType.warning,
    duration: const Duration(seconds: 8),
    actionLabel: 'Open app settings',
    onAction: () => unawaited(access.openSettings()),
  );
}

/// "Grant Access" from Home, Browse and the access snackbars: asks (opening the OS page where that is
/// the way), and when the user comes back without access keeps checking for a few seconds in case the
/// grant is late. [onGranted] runs once access shows up. If it never does, [guide] (guidance with
/// "Open app settings") runs once; by default the shared snackbar. A grant on the first answer shows
/// no guidance.
Future<void> requestStorageAccessFlow({
  required StorageAccessService access,
  FutureOr<void> Function()? onGranted,
  bool Function()? isClosed,
  AccessRecheck? recheck,
  void Function()? guide,
}) async {
  if (await access.requestOrOpenSettings()) {
    await onGranted?.call();
    return;
  }
  var granted = false;
  await (recheck ?? AccessRecheck()).run(
    check: () async {
      if (granted || !await access.hasAccess()) return;
      granted = true;
      await onGranted?.call();
    },
    changed: () => granted,
    isClosed: isClosed,
    onSettled: guide ?? () => showStorageAccessGuidance(access),
  );
}
