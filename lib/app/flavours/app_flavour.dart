import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:openreader/core/data/cache/client/preference_cache.dart';
import 'package:openreader/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  final crashReporting = await _initFirebase();

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
    // `log` reaches only the VM service; in debug also print the report, so
    // errors like a failed layout show in logcat/the console instead of a
    // silently blank screen.
    if (kDebugMode) FlutterError.presentError(details);
    if (crashReporting) FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  if (crashReporting) {
    // Async/zone errors that never reach FlutterError.onError.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  _initialize();
  // Date symbols for every supported locale (en, bn) - formatDocumentDate.
  await initializeDateFormatting();
  runApp(await builder());
}

/// Firebase (project `chowdhuryelab`) is configured for Android and iOS only.
/// Collection is off in debug so development crashes don't pollute reports.
/// Never lets a Firebase failure block app start. Returns whether Crashlytics
/// is active.
Future<bool> _initFirebase() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(!kDebugMode);
    return true;
  } catch (e, s) {
    log('Firebase init failed: $e', stackTrace: s);
    return false;
  }
}

void _initialize() {
  _initDesktopDatabase();
  Get.lazyPut<PreferenceCache>(() => PreferenceCache(), fenix: true);
}

/// sqflite only ships Android/iOS/macOS implementations; Windows and Linux
/// (and, to keep one code path, macOS) use the FFI factory instead.
void _initDesktopDatabase() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
