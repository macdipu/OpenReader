import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/presentation/utils/platform_info.dart';

/// Storage access as shown in Settings. [notApplicable] on iOS and desktop, where there is
/// no broad storage permission to grant.
enum StorageAccessState { allowed, notAllowed, blocked, notApplicable }

/// The phone maker's Settings app family, which decides how the All files access steps read.
/// [other] is stock Android (Google Pixel, Motorola, Nokia, ...) and the fallback for anything unknown.
enum DeviceBrand {
  samsung,
  coloros,
  hyperos,
  vivo,
  other;

  /// Maps the lowercased `Build.MANUFACTURER` and `Build.BRAND` to a family.
  static DeviceBrand fromNames(String? manufacturer, String? brand) {
    for (final raw in [manufacturer, brand]) {
      final name = (raw ?? '').trim().toLowerCase();
      switch (name) {
        case 'samsung':
          return samsung;
        case 'oppo':
        case 'realme':
        case 'oneplus':
          return coloros;
        case 'xiaomi':
        case 'redmi':
        case 'poco':
          return hyperos;
        case 'vivo':
        case 'iqoo':
          return vivo;
      }
    }
    return other;
  }
}

/// Wraps the platform permission(s) OpenReader needs to discover documents
/// anywhere on local storage (BRD 9.2 - Storage Access / Onboarding).
///
/// Android 11+ scopes broad filesystem reads behind MANAGE_EXTERNAL_STORAGE,
/// a "special app access" the user grants from Settings, not the normal
/// runtime permission dialog. Below Android 13, READ_EXTERNAL_STORAGE covers
/// it. iOS has no equivalent concept; document access there is expected to
/// come from the Files app / document picker in a later phase.
class StorageAccessService {
  StorageAccessService._()
      : _sdkReader = _readSdkFromPlatform,
        _brandReader = _readBrandFromPlatform,
        _allFilesOpener = _openAllFilesFromPlatform;

  /// Test constructor: [sdkReader] stands in for the Android SDK level lookup, [brandReader] for the
  /// phone brand lookup.
  @visibleForTesting
  StorageAccessService.test(Future<int?> Function() sdkReader,
      {Future<DeviceBrand> Function()? brandReader, Future<bool> Function()? allFilesOpener})
      : _sdkReader = sdkReader,
        _brandReader = brandReader ?? (() async => DeviceBrand.other),
        _allFilesOpener = allFilesOpener ?? _openAllFilesFromPlatform;

  static final StorageAccessService instance = StorageAccessService._();

  /// Android 11 (API 30): from here on broad file reads need "All files access" only. The legacy
  /// "photos and media" permission grants media files, never documents.
  static const allFilesApiLevel = 30;

  static const _deviceChannel = MethodChannel('openreader/device');

  final Future<int?> Function() _sdkReader;
  final Future<DeviceBrand> Function() _brandReader;
  final Future<bool> Function() _allFilesOpener;
  int? _sdkInt;
  DeviceBrand? _brand;

  /// Native: opens the All files access page (app-specific, then the general list, then app info).
  /// True when some page opened.
  static Future<bool> _openAllFilesFromPlatform() async =>
      await _deviceChannel.invokeMethod<bool>('openAllFilesAccess') ?? false;

  static Future<DeviceBrand> _readBrandFromPlatform() async {
    if (!PlatformInfo.isAndroid) return DeviceBrand.other;
    final info = await _deviceChannel.invokeMapMethod<String, String>('brand');
    return DeviceBrand.fromNames(info?['manufacturer'], info?['brand']);
  }

  /// The brand once [deviceBrand] has answered, else null. Lets text that cannot wait for a lookup
  /// (the guidance snackbar) read it synchronously.
  DeviceBrand? get cachedBrand => _brand;

  /// The phone brand family, read once and cached. [DeviceBrand.other] when it cannot be read or off
  /// Android (nothing is cached after a failure, so the next call tries again).
  Future<DeviceBrand> deviceBrand() async {
    final cached = _brand;
    if (cached != null) return cached;
    if (!PlatformInfo.isAndroid) return DeviceBrand.other;
    try {
      return _brand = await _brandReader();
    } catch (_) {
      return DeviceBrand.other;
    }
  }

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

  /// Android 11+: the OS "All files access" page for this app, where the switch lives. Unlike
  /// [Permission.manageExternalStorage].request() it opens even when access is already granted, so it
  /// also serves to revoke. The app info page is only the fallback (it has no such switch on Android
  /// 11+). Android 10 and older, and other platforms: the app's settings page, where Permissions >
  /// Storage is.
  Future<bool> openAllFilesAccessSettings() async {
    if (!PlatformInfo.isAndroid || await _usesLegacyStoragePermission()) return openSettings();
    try {
      if (await _allFilesOpener()) return true;
    } catch (_) {}
    return openSettings();
  }

  /// Asks for access in the way the Android version supports. API 30+: opens the "All files access"
  /// page directly and reports whether it was granted once the user is back. API 29 and below: the
  /// runtime prompt, then the app's settings page when the OS will no longer show it (permanently
  /// denied), so a "Grant Access" button is never a dead end. A grant made later is picked up by the
  /// app-resume re-check.
  Future<bool> requestOrOpenSettings() async {
    if (PlatformInfo.isAndroid && !await _usesLegacyStoragePermission()) {
      if (await hasAccess()) return true;
      // The request opens the same page and resolves when the user is back, which the result needs.
      try {
        await Permission.manageExternalStorage.request();
      } catch (_) {
        await openSettings();
      }
      return hasAccess();
    }
    if (await requestAccess()) return true;
    if (await isPermanentlyDenied()) await openSettings();
    return false;
  }
}
