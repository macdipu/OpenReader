import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:openreader/core/data/cache/client/preference_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
    // `log` reaches only the VM service; in debug also print the report, so
    // errors like a failed layout show in logcat/the console instead of a
    // silently blank screen.
    if (kDebugMode) FlutterError.presentError(details);
  };

  _initialize();
  // Date symbols for every supported locale (en, bn) - formatDocumentDate.
  await initializeDateFormatting();
  runApp(await builder());
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
