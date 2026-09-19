import 'dart:async';
import 'dart:developer';

import 'package:openreader/core/data/cache/client/preference_cache.dart';
import 'package:openreader/services/push_notification/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  // TODO: Enable Firebase for production:
  // await Firebase.initializeApp();
  // await NotificationService().init();

  _initialize();
  runApp(await builder());
}

void _initialize() {
  Get.lazyPut<PreferenceCache>(() => PreferenceCache(), fenix: true);
  Get.lazyPut<NotificationService>(() => NotificationService(), fenix: true);
}
