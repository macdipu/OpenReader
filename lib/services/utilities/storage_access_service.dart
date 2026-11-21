import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/presentation/utils/platform_info.dart';

/// Storage access as shown in Settings. [notApplicable] on iOS and desktop, where there is
/// no broad storage permission to grant.
enum StorageAccessState { allowed, notAllowed, blocked, notApplicable }

/// Wraps the platform permission(s) OpenReader needs to discover documents
/// anywhere on local storage (BRD 9.2 - Storage Access / Onboarding).
///
/// Android 11+ scopes broad filesystem reads behind MANAGE_EXTERNAL_STORAGE,
/// a "special app access" the user grants from Settings, not the normal
/// runtime permission dialog. Below Android 13, READ_EXTERNAL_STORAGE covers
/// it. iOS has no equivalent concept; document access there is expected to
/// come from the Files app / document picker in a later phase.
class StorageAccessService {
  StorageAccessService._() : _sdkReader = _readSdkFromPlatform;

  /// Test constructor: [sdkReader] stands in for the Android SDK level lookup.
  @visibleForTesting
  StorageAccessService.test(Future<int?> Function() sdkReader) : _sdkReader = sdkReader;

  static final StorageAccessService instance = StorageAccessService._();

  /// Android 11 (API 30): from here on broad file reads need "All files access" only. The legacy
  /// "photos and media" permission grants media files, never documents.
  static const allFilesApiLevel = 30;

  static const _deviceChannel = MethodChannel('openreader/device');

  final Future<int?> Function() _sdkReader;
  int? _sdkInt;

  static Future<int?> _readSdkFromPlatform() async {
    try {
      return await _deviceChannel.invokeMethod<int>('sdkInt');
    } catch (_) {
      return null;
    }
  }

  /// The Android SDK level, read once and cached. Null when it cannot be read (nothing is cached
  /// then, so the next call tries again).
  Future<int?> androidSdkInt() async {
    final cached = _sdkInt;
    if (cached != null) return cached;
    try {
      return _sdkInt = await _sdkReader();
    } catch (_) {
      return null;
    }
  }

  /// True on API 29 and below, where the runtime storage permission is the right one. An unreadable
  /// SDK level counts as Android 11 or newer.
  Future<bool> _usesLegacyStoragePermission() async {
    final sdk = await androidSdkInt();
    return sdk != null && sdk < allFilesApiLevel;
  }

  Future<bool> hasAccess() async {
    if (!PlatformInfo.isAndroid) return true;
    if (await _usesLegacyStoragePermission()) {
      return await Permission.storage.isGranted || await Permission.manageExternalStorage.isGranted;
    }
    // Android 11+: only All files access lists documents.
    return Permission.manageExternalStorage.isGranted;
  }

  /// Returns true if access was granted. On Android 11+ this hands off to the OS "All files access"
  /// settings screen (never the legacy media dialog) and resolves when the user comes back.
  Future<bool> requestAccess() async {
    if (!PlatformInfo.isAndroid) return true;
    if (await _usesLegacyStoragePermission()) {
      return (await Permission.storage.request()).isGranted;
    }
    return (await Permission.manageExternalStorage.request()).isGranted;
  }

  /// Only the legacy storage permission can be permanently denied in a way the user must undo by hand.
  /// Android 11+ has no such state for All files access: the page can always be opened.
  Future<bool> isPermanentlyDenied() async {
    if (!PlatformInfo.isAndroid) return false;
    if (!await _usesLegacyStoragePermission()) return false;
    return (await Permission.storage.status).isPermanentlyDenied;
  }

  /// Current state for display. Only Android has a permission to report; elsewhere
  /// [StorageAccessState.notApplicable].
  Future<StorageAccessState> state() async {
    if (!PlatformInfo.isAndroid) return StorageAccessState.notApplicable;
    return stateFrom(granted: await hasAccess(), permanentlyDenied: await isPermanentlyDenied());
  }

  @visibleForTesting
  static StorageAccessState stateFrom({required bool granted, required bool permanentlyDenied}) {
    if (granted) return StorageAccessState.allowed;
    return permanentlyDenied ? StorageAccessState.blocked : StorageAccessState.notAllowed;
  }

  Future<bool> openSettings() => openAppSettings();

  /// Android: the OS "All files access" page for this app (Android 11+), the exact screen where the
  /// switch lives. [Permission.manageExternalStorage] opens it as its request. Anywhere else, or if it
  /// cannot be opened, the app's general settings page is the fallback so the user is never stranded.
  Future<bool> openAllFilesAccessSettings() async {
    if (!PlatformInfo.isAndroid) return openSettings();
    try {
      await Permission.manageExternalStorage.request();
      return true;
    } catch (_) {
      return openSettings();
    }
  }

  /// Asks for access in the way the Android version supports. API 30+: opens the "All files access"
  /// page directly and reports whether it was granted once the user is back. API 29 and below: the
  /// runtime prompt, then the app's settings page when the OS will no longer show it (permanently
  /// denied), so a "Grant Access" button is never a dead end. A grant made later is picked up by the
  /// app-resume re-check.
  Future<bool> requestOrOpenSettings() async {
    if (PlatformInfo.isAndroid && !await _usesLegacyStoragePermission()) {
      if (await hasAccess()) return true;
      await openAllFilesAccessSettings();
      return hasAccess();
    }
    if (await requestAccess()) return true;
    if (await isPermanentlyDenied()) await openSettings();
    return false;
  }
}
