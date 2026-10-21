import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:openreader/core/data/cache/client/preference_cache.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  _initialize();
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
