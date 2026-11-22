import 'dart:async';

import 'package:drop/drop/widgets/drop_connectivity_banner.dart';
import 'package:drop/screens/SplashScreen.dart' show BootTarget, decideBootTarget;
import 'package:drop/service/net/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('first screen is decided from what is saved, never from the network', () {
    test('first launch shows onboarding', () {
      expect(decideBootTarget(firstTime: true, loggedIn: false, token: '', contactNumber: ''), BootTarget.onboarding);
    });
    test('no session shows sign-in', () {
      expect(decideBootTarget(firstTime: false, loggedIn: false, token: '', contactNumber: ''), BootTarget.signIn);
    });
    test('a saved sign-in flag without a token is not a session', () {
      expect(decideBootTarget(firstTime: false, loggedIn: true, token: '', contactNumber: '0803'), BootTarget.signIn);
    });
    test('signed in but profile unfinished completes the profile', () {
      expect(decideBootTarget(firstTime: false, loggedIn: true, token: 't', contactNumber: ''), BootTarget.completeProfile);
    });
    test('a saved session opens the app at once', () {
      expect(decideBootTarget(firstTime: false, loggedIn: true, token: 't', contactNumber: '0803'), BootTarget.home);
    });
  });

  group('connectivity wording', () {
    test('online says nothing; every other state explains itself', () {
      expect(dropConnectivityMessage(NetStatus.online), isNull);
      expect(dropConnectivityMessage(NetStatus.offline), 'No internet connection. You are viewing saved information.');
      expect(dropConnectivityMessage(NetStatus.degraded), contains('Weak connection'));
      expect(dropConnectivityMessage(NetStatus.reconnecting), contains('Reconnecting'));
      expect(dropConnectivityMessage(NetStatus.serverDown), contains('not responding'));
    });
  });

  group('connectivity strip', () {
    late StreamController<bool> link;
    late ConnectivityService svc;

    setUp(() {
      link = StreamController<bool>.broadcast();
      svc = ConnectivityService(linkChanges: link.stream, checkLink: () async => true, probe: () async => true);
    });

    Widget app() => MaterialApp(
          home: DropConnectivityHost(
            service: svc,
            child: Scaffold(body: Center(child: ElevatedButton(onPressed: () {}, child: const Text('Request ride')))),
          ),
        );

    testWidgets('shows nothing while online, and the screen is fully usable', (t) async {
      await t.pumpWidget(app());
      expect(find.byKey(const Key('connectivity_banner')), findsNothing);
      expect(find.text('Request ride'), findsOneWidget);
    });

    testWidgets('offline: a slim strip appears above the screen, the screen stays tappable', (t) async {
      await t.pumpWidget(app());
      svc.status.value = NetStatus.offline;
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('connectivity_banner')), findsOneWidget);
      expect(find.text('No internet connection. You are viewing saved information.'), findsOneWidget);
      // not a blocking page: the button is still there and tappable
      expect(find.text('Request ride'), findsOneWidget);
      await t.tap(find.text('Request ride'));
      // it sits above the content instead of covering it
      expect(t.getRect(find.byKey(const Key('connectivity_banner'))).bottom <= t.getRect(find.byType(Scaffold)).top + 0.5, isTrue);
    });

    testWidgets('coming back says so for a moment, then goes away', (t) async {
      await t.pumpWidget(app());
      svc.status.value = NetStatus.offline;
      await t.pump();
      svc.status.value = NetStatus.online;
      svc.recoveries.value++;
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('You are back online.'), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('connectivity_banner')), findsNothing);
    });
  });
}
