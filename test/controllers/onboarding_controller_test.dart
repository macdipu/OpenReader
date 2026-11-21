import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:openreader/features/onboarding/presentation/onboarding_controller.dart';
import 'package:openreader/res/routes/app_routes.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';

class _Access implements StorageAccessService {
  bool granted = false;
  int checks = 0;

  @override
  Future<bool> requestAccess() async => granted;

  @override
  Future<bool> isPermanentlyDenied() async => false;

  @override
  Future<bool> hasAccess() async {
    checks++;
    return granted;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements AppSettingsRepository {
  bool complete = false;

  @override
  Future<void> setOnboardingComplete(bool value) async => complete = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Access access;
  late _Settings settings;
  late OnboardingController controller;

  setUp(() {
    Get.testMode = true;
    access = _Access();
    settings = _Settings();
  });

  tearDown(Get.reset);

  Future<void> pumpApp(WidgetTester tester) async {
    controller = OnboardingController(storageAccess: access, settingsRepository: settings);
    await tester.pumpWidget(GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const Scaffold(body: Text('onboarding'))),
        GetPage(name: AppRoutes.appShell, page: () => const Scaffold(body: Text('shell'))),
      ],
    ));
    Get.put(controller);
  }

  testWidgets('a grant that reaches the app after the OS page finishes onboarding (A-12)', (tester) async {
    await pumpApp(tester);
    await controller.allowAccess();
    expect(controller.status.value, OnboardingStatus.denied);
    access.granted = true;
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(settings.complete, isTrue);
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('coming back to the app re-checks over a few seconds', (tester) async {
    await pumpApp(tester);
    await controller.allowAccess();
    await tester.pump(const Duration(seconds: 4));
    final before = access.checks;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(access.checks, before + 1);
    access.granted = true;
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(settings.complete, isTrue);
  });

  testWidgets('without a grant it keeps the denied screen and stops checking', (tester) async {
    await pumpApp(tester);
    await controller.allowAccess();
    await tester.pump(const Duration(seconds: 4));
    final checks = access.checks;
    await tester.pump(const Duration(seconds: 10));
    expect(access.checks, checks);
    expect(settings.complete, isFalse);
    expect(controller.status.value, OnboardingStatus.denied);
  });
}
