import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openreader/core/presentation/theme/app_theme.dart';
import 'package:openreader/features/settings/presentation/sections/update_sheet.dart';
import 'package:openreader/services/utilities/update_checker.dart';
import 'package:openreader/services/utilities/update_decision.dart';

class _Actions implements UpdateActions {
  final calls = <String>[];
  @override
  Future<void> startStoreUpdate(UpdateCheck check) async => calls.add('store');
  @override
  Future<void> openStore(UpdateCheck check) async => calls.add('openStore');
  @override
  Future<void> downloadEarlyBuild(UpdateCheck check) async => calls.add('early');
  @override
  Future<void> installFromGitHub(UpdateCheck check) async => calls.add('install');
}

GithubRelease _github(String tag) => GithubRelease(tag: tag, pageUrl: 'https://github.com/x/$tag');

UpdateCheck _check({
  UpdatePlatform platform = UpdatePlatform.android,
  String installed = '1.0.23',
  UpdateOffer offer = const UpdateOffer(storeUpdate: false),
  String? storeName = 'Google Play',
  String? label = 'v1.0.23',
  bool storeUnreachable = false,
  bool githubUnreachable = false,
}) => UpdateCheck(
  installed: installed,
  platform: platform,
  offer: offer,
  storeName: storeName,
  storeVersionLabel: label,
  storeUnreachable: storeUnreachable,
  githubUnreachable: githubUnreachable,
);

void main() {
  late _Actions actions;

  Future<void> show(WidgetTester tester, Future<UpdateCheck> check) async {
    actions = _Actions();
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: UpdateSheet(check: check, actions: actions))));
    await tester.pump();
  }

  testWidgets('while checking it says so', (tester) async {
    await show(tester, Future<UpdateCheck>.delayed(const Duration(hours: 1), _check));
    expect(find.byKey(const Key('update-checking')), findsOneWidget);
    expect(find.text('Checking for updates…'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(hours: 2));
  });

  testWidgets('up to date: the store\'s version first, no early build, no buttons', (tester) async {
    await show(tester, Future.value(_check()));
    await tester.pump();
    expect(find.text('Installed: v1.0.23'), findsOneWidget);
    expect(find.text('Google Play'), findsOneWidget);
    expect(find.text('v1.0.23'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.byKey(const Key('update-early-build')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('an update on the store: its version and an Update on Google Play button', (tester) async {
    await show(tester, Future.value(_check(offer: const UpdateOffer(storeUpdate: true), label: 'v1.0.24')));
    await tester.pump();
    expect(find.text('v1.0.24'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.byKey(const Key('update-early-build')), findsNothing);
    await tester.tap(find.text('Update on Google Play'));
    expect(actions.calls, ['store']);
  });

  testWidgets('GitHub newer than the store: Early Build Available below the store, with Download Early Build', (tester) async {
    await show(tester, Future.value(_check(offer: UpdateOffer(storeUpdate: false, github: _github('v1.0.25')))));
    await tester.pump();
    // The store card is there and first; the early build is a second card under it.
    expect(find.byKey(const Key('update-store')), findsOneWidget);
    expect(find.byKey(const Key('update-early-build')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('update-store'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('update-early-build'))).dy));
    expect(find.text('Early Build Available'), findsOneWidget);
    expect(find.text('v1.0.25'), findsOneWidget);
    expect(find.textContaining('GitHub has a newer version than Google Play'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget, reason: 'the store itself is still up to date');
    await tester.tap(find.text('Download Early Build'));
    expect(actions.calls, ['early']);
  });

  testWidgets('an update in the store and an even newer GitHub build: both, the store first', (tester) async {
    await show(tester, Future.value(_check(offer: UpdateOffer(storeUpdate: true, github: _github('v1.0.25')), label: 'v1.0.24')));
    await tester.pump();
    expect(find.text('Update on Google Play'), findsOneWidget);
    expect(find.text('Download Early Build'), findsOneWidget);
    expect(find.text('v1.0.24'), findsOneWidget);
    expect(find.text('v1.0.25'), findsOneWidget);
  });

  testWidgets('the App Store is the store on iOS and the button opens it', (tester) async {
    await show(tester, Future.value(_check(platform: UpdatePlatform.ios, storeName: 'App Store', label: 'v1.0.24', offer: const UpdateOffer(storeUpdate: true))));
    await tester.pump();
    expect(find.text('App Store'), findsOneWidget);
    await tester.tap(find.text('Open App Store'));
    expect(actions.calls, ['openStore']);
  });

  testWidgets('a store that could not be reached is said so, and GitHub can still offer its build', (tester) async {
    await show(tester, Future.value(_check(storeUnreachable: true, offer: UpdateOffer(storeUpdate: false, github: _github('v1.0.24'), githubIsMainSource: true))));
    await tester.pump();
    expect(find.byKey(const Key('update-github-main')), findsOneWidget);
    expect(find.text('Download update'), findsOneWidget);
    expect(find.byKey(const Key('update-store-unreachable')), findsOneWidget, reason: 'says why it is GitHub and not the store');
  });

  testWidgets('desktop: GitHub is the release to update to, installed in the app', (tester) async {
    await show(tester, Future.value(_check(platform: UpdatePlatform.desktop, storeName: null, label: null, offer: UpdateOffer(storeUpdate: false, github: _github('v1.0.24'), githubIsMainSource: true))));
    await tester.pump();
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('v1.0.24'), findsOneWidget);
    expect(find.text('Early Build Available'), findsNothing, reason: 'on desktop it is the release, not an early build');
    await tester.tap(find.text('Download and install'));
    expect(actions.calls, ['install']);
  });

  testWidgets('desktop, up to date', (tester) async {
    await show(tester, Future.value(_check(platform: UpdatePlatform.desktop, storeName: null, label: null, offer: const UpdateOffer(storeUpdate: false, githubIsMainSource: true))));
    await tester.pump();
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('v1.0.23'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('when nothing could be asked, it says so', (tester) async {
    await show(tester, Future.value(_check(storeUnreachable: true, githubUnreachable: true, offer: const UpdateOffer(storeUpdate: false, githubIsMainSource: true))));
    await tester.pump();
    expect(find.textContaining('Could not check for updates'), findsOneWidget);
  });

  testWidgets('a check that threw says so too', (tester) async {
    final failing = Future<UpdateCheck>.error(Exception('boom'))..ignore();
    await show(tester, failing);
    await tester.pump();
    expect(find.textContaining('Could not check for updates'), findsOneWidget);
  });
}
