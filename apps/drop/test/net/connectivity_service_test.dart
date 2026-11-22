import 'dart:async';

import 'package:drop/service/net/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

class Harness {
  final link = StreamController<bool>.broadcast();
  bool linkUp = true;
  bool serverUp = true;
  int probes = 0;
  DateTime clock = DateTime(2026, 1, 1);
  late final ConnectivityService svc = ConnectivityService(
    linkChanges: link.stream,
    checkLink: () async => linkUp,
    probe: () async {
      probes++;
      return serverUp;
    },
    retryDelay: (a) => const Duration(milliseconds: 20),
    minProbeGap: const Duration(seconds: 10),
    now: () => clock,
  );
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('starts online and starts nothing until asked', () {
    final h = Harness();
    expect(h.svc.status.value, NetStatus.online);
    expect(h.svc.isOffline, isFalse);
    expect(h.probes, 0);
  });

  test('no device link at start means offline, with no network call', () async {
    final h = Harness()..linkUp = false;
    await h.svc.start();
    expect(h.svc.status.value, NetStatus.offline);
    expect(h.probes, 0);
  });

  test('losing the link is offline; getting it back checks DROP before saying online', () async {
    final h = Harness();
    await h.svc.start();
    h.link.add(false);
    await settle();
    expect(h.svc.status.value, NetStatus.offline);
    expect(h.svc.isOffline, isTrue);

    final seen = <NetStatus>[];
    h.svc.status.addListener(() => seen.add(h.svc.status.value));
    h.linkUp = true;
    h.link.add(true);
    await settle();
    expect(seen.first, NetStatus.reconnecting);
    expect(h.svc.status.value, NetStatus.online);
    expect(h.probes, 1);
    expect(h.svc.recoveries.value, 1);
  });

  test('link up but DROP not answering is serverDown, and it keeps trying until DROP answers', () async {
    final h = Harness()..serverUp = false;
    await h.svc.start();
    h.link.add(false);
    await settle();
    h.link.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(h.svc.status.value, NetStatus.serverDown);
    expect(h.probes, greaterThan(1));
    h.serverUp = true;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(h.svc.status.value, NetStatus.online);
    expect(h.svc.recoveries.value, 1);
  });

  test('a successful real request means online, whatever the last check said', () async {
    final h = Harness()..serverUp = false;
    await h.svc.start();
    await h.svc.probeNow(force: true);
    expect(h.svc.status.value, NetStatus.serverDown);
    h.svc.reportSuccess();
    expect(h.svc.status.value, NetStatus.online);
  });

  test('repeated timeouts mean a weak connection; one success clears it', () async {
    final h = Harness();
    await h.svc.start();
    h.svc.reportFailure(timeout: true);
    expect(h.svc.status.value, NetStatus.online);
    h.svc.reportFailure(timeout: true);
    expect(h.svc.status.value, NetStatus.degraded);
    h.svc.reportSuccess();
    expect(h.svc.status.value, NetStatus.online);
  });

  test('a burst of failures asks DROP once, not once per failure', () async {
    final h = Harness();
    await h.svc.start();
    for (var i = 0; i < 6; i++) {
      h.svc.reportFailure(timeout: false);
    }
    await settle();
    expect(h.probes, 1);
    h.clock = h.clock.add(const Duration(seconds: 11));
    h.svc.reportFailure(timeout: false);
    h.svc.reportFailure(timeout: false);
    await settle();
    expect(h.probes, 2);
  });

  test('failures are ignored while offline: the link is already known to be down', () async {
    final h = Harness();
    await h.svc.start();
    h.link.add(false);
    await settle();
    h.svc.reportFailure(timeout: true);
    h.svc.reportFailure(timeout: true);
    expect(h.svc.status.value, NetStatus.offline);
    expect(h.probes, 0);
  });

  test('coming back to the app while not fully online checks again at once', () async {
    final h = Harness()..serverUp = false;
    await h.svc.start();
    await h.svc.probeNow(force: true);
    final before = h.probes;
    h.serverUp = true;
    h.svc.onResume();
    await settle();
    expect(h.probes, before + 1);
    expect(h.svc.status.value, NetStatus.online);
  });

  test('default retry delays grow and stop at a minute', () {
    final d = List.generate(8, ConnectivityService.defaultRetryDelay);
    expect(d.first, const Duration(seconds: 5));
    expect(d[1], const Duration(seconds: 10));
    expect(d[2], const Duration(seconds: 20));
    expect(d.last, const Duration(seconds: 60));
    for (var i = 1; i < d.length; i++) {
      expect(d[i] >= d[i - 1], isTrue);
    }
  });
}
