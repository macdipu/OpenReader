import 'dart:async';
import 'dart:developer';

import 'package:openreader/core/data/cache/client/preference_cache.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  _initialize();
  runApp(await builder());
}

void _initialize() {
  Get.lazyPut<PreferenceCache>(() => PreferenceCache(), fenix: true);
}
