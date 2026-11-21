import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/app/shell/app_shell.dart';
import 'package:openreader/app/shell/app_shell_controller.dart';

/// N-02: Back on the narrow shell. The shell sits on a base route so "leaving the app" shows as the
/// shell route popping.
void main() {
  group('backGoesToHome', () {
    test('Browse and Favorites go to Home; Home and Settings are left alone', () {
      expect(backGoesToHome(index: AppShellController.filesIndex, browseCanGoUp: false), isTrue);
      expect(backGoesToHome(index: AppShellController.favoritesIndex, browseCanGoUp: false), isTrue);
      expect(backGoesToHome(index: AppShellController.homeIndex, browseCanGoUp: false), isFalse);
      expect(backGoesToHome(index: AppShellController.settingsIndex, browseCanGoUp: false), isFalse);
    });

    test('Browse goes up a folder first', () {
      expect(backGoesToHome(index: AppShellController.filesIndex, browseCanGoUp: true), isFalse);
      expect(backGoesToHome(index: AppShellController.favoritesIndex, browseCanGoUp: true), isTrue);
    });
  });

  group('ShellBackScope', () {
    late ValueNotifier<int> index;
    late ValueNotifier<bool> browseCanGoUp;
    late int goUps;

    setUp(() {
      index = ValueNotifier(AppShellController.homeIndex);
      browseCanGoUp = ValueNotifier(false);
      goUps = 0;
    });

    Future<void> pumpShell(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ListenableBuilder(
                  listenable: Listenable.merge([index, browseCanGoUp]),
                  builder: (_, __) => ShellBackScope(
                    index: index.value,
                    browseCanGoUp: browseCanGoUp.value,
                    onGoHome: () => index.value = AppShellController.homeIndex,
                    // Stands in for Browse's own PopScope (folder up), active on the Browse tab.
                    child: PopScope(
                      canPop: !(index.value == AppShellController.filesIndex && browseCanGoUp.value),
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) {
                          goUps++;
                          browseCanGoUp.value = false;
                        }
                      },
                      child: const Scaffold(body: Text('shell')),
                    ),
                  ),
                ),
              )),
              child: const Text('open shell'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open shell'));
      await tester.pumpAndSettle();
    }

    Future<void> back(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    testWidgets('Back on Home leaves the shell (exits the app)', (tester) async {
      await pumpShell(tester);
      await back(tester);
      expect(find.text('shell'), findsNothing);
    });

    testWidgets('Back on Browse goes to Home, then Back leaves', (tester) async {
      await pumpShell(tester);
      index.value = AppShellController.filesIndex;
      await tester.pump();
      await back(tester);
      expect(find.text('shell'), findsOneWidget);
      expect(index.value, AppShellController.homeIndex);
      await back(tester);
      expect(find.text('shell'), findsNothing);
    });

    testWidgets('Back on Favorites goes to Home', (tester) async {
      await pumpShell(tester);
      index.value = AppShellController.favoritesIndex;
      await tester.pump();
      await back(tester);
      expect(find.text('shell'), findsOneWidget);
      expect(index.value, AppShellController.homeIndex);
    });

    testWidgets('Browse folder-up keeps priority over going Home', (tester) async {
      await pumpShell(tester);
      index.value = AppShellController.filesIndex;
      browseCanGoUp.value = true;
      await tester.pump();
      await back(tester);
      expect(goUps, 1);
      expect(index.value, AppShellController.filesIndex, reason: 'folder up, not Home');
      await back(tester);
      expect(index.value, AppShellController.homeIndex, reason: 'at the roots Back goes Home');
      expect(find.text('shell'), findsOneWidget);
    });
  });
}
