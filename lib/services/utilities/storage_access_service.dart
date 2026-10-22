import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Wraps the platform permission(s) OpenReader needs to discover documents
/// anywhere on local storage (BRD 9.2 - Storage Access / Onboarding).
///
/// Android 11+ scopes broad filesystem reads behind MANAGE_EXTERNAL_STORAGE,
/// a "special app access" the user grants from Settings, not the normal
/// runtime permission dialog. Below Android 13, READ_EXTERNAL_STORAGE covers
/// it. iOS has no equivalent concept; document access there is expected to
/// come from the Files app / document picker in a later phase.
class StorageAccessService {
  StorageAccessService._();
  static final StorageAccessService instance = StorageAccessService._();

  Future<bool> hasAccess() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    return Permission.storage.isGranted;
  }

  /// Returns true if access was granted. On Android 11+ this may hand off to
  /// the OS "All files access" settings screen rather than an in-app dialog.
  Future<bool> requestAccess() async {
    if (!Platform.isAndroid) return true;

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;
    final manage = await Permission.manageExternalStorage.status;
    final storage = await Permission.storage.status;
    return manage.isPermanentlyDenied && storage.isPermanentlyDenied;
  }

  Future<bool> openSettings() => openAppSettings();

  /// [requestAccess], falling back to the app's system settings page when
  /// the OS will no longer show a prompt (permanently denied), so a "Grant
  /// Access" button is never a dead end. Returns whether access is granted
  /// now; a grant made in settings is picked up by the app-resume re-check.
  Future<bool> requestOrOpenSettings() async {
    if (await requestAccess()) return true;
    if (await isPermanentlyDenied()) await openSettings();
    return false;
  }
}
