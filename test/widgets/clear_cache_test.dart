import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:openreader/core/domain/repositories/recent_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/features/settings/presentation/settings_controller.dart';
import 'package:openreader/services/utilities/path_service.dart';

class _TempPathService implements PathService {
  _TempPathService(this.dir);
  final Directory dir;
  @override
  ResultFuture<Directory> getTempDirectory() async => Right(dir);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements AppSettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recents implements RecentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Clear cache keeps the incoming documents and the update download', (tester) async {
    final temp = Directory.systemTemp.createTempSync('clear_cache');
    addTearDown(() => temp.deleteSync(recursive: true));
    File('${temp.path}/document_thumbnails/a.png').createSync(recursive: true);
    File('${temp.path}/incoming/doc.pdf').createSync(recursive: true);
    File('${temp.path}/openreader_update/setup.exe').createSync(recursive: true);
    File('${temp.path}/loose.tmp').createSync();
    Get.testMode = true;
    final c = SettingsController(pathService: _TempPathService(temp), settings: _Settings(), recents: _Recents());
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
    await tester.runAsync(() async => c.clearCache());
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(File('${temp.path}/document_thumbnails/a.png').existsSync(), isFalse);
    expect(File('${temp.path}/loose.tmp').existsSync(), isFalse);
    expect(File('${temp.path}/incoming/doc.pdf').existsSync(), isTrue);
    expect(File('${temp.path}/openreader_update/setup.exe').existsSync(), isTrue);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    Get.reset();
  });
}
