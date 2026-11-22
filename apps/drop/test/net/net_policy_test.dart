import 'dart:async';
import 'dart:math';

import 'package:drop/service/DriverApplicationApi.dart' show ApiFailure;
import 'package:drop/service/net/connectivity_service.dart';
import 'package:drop/service/net/net_policy.dart';
import 'package:flutter_test/flutter_test.dart';

ConnectivityService fakeConnectivity({bool linkUp = true}) => ConnectivityService(
      linkChanges: const Stream<bool>.empty(),
      checkLink: () async => linkUp,
      probe: () async => true,
      retryDelay: (_) => const Duration(milliseconds: 5),
    );

void main() {
  late ConnectivityService conn;
  late List<Duration> slept;

  setUp(() {
    conn = fakeConnectivity();
    slept = [];
    NetGate.connectivity = conn;
    NetGate.sleep = (d) async => slept.add(d);
    NetGate.backoff = Backoff(random: Random(1));
  });

  group('backoff', () {
    test('grows with each attempt, never past the cap, and is jittered', () {
      final b = Backoff(base: const Duration(milliseconds: 400), cap: const Duration(seconds: 6), random: Random(7));
      final d = List.generate(10, b.delay);
      for (final x in d) {
        expect(x <= const Duration(seconds: 6), isTrue);
        expect(x >= const Duration(milliseconds: 200), isTrue);
      }
      expect(d[3] > d[0], isTrue);
      final other = Backoff(random: Random(99));
      expect(List.generate(6, other.delay), isNot(equals(List.generate(6, b.delay).take(6).toList())));
    });
  });

  group('writes', () {
    test('are refused at once when offline, without sending anything', () async {
      await conn.start();
      var sent = 0;
      final offline = fakeConnectivity(linkUp: false);
      await offline.start();
      NetGate.connectivity = offline;
      await expectLater(
        NetGate.write((t) async {
          sent++;
          return {};
        }),
        throwsA(isA<ApiFailure>().having((e) => e.offline, 'offline', true).having((e) => e.message, 'message', NetGate.offlineMessage)),
      );
      expect(sent, 0);
    });

    test('a timeout after sending is reported as unconfirmed, never as a plain failure, and is not retried', () async {
      var sent = 0;
      await expectLater(
        NetGate.write((t) async {
          sent++;
          throw TimeoutException('slow');
        }),
        throwsA(isA<ApiFailure>().having((e) => e.unconfirmed, 'unconfirmed', true).having((e) => e.message, 'message', NetGate.unconfirmedMessage)),
      );
      expect(sent, 1);
      expect(slept, isEmpty);
    });

    test('a refusal from the server passes through untouched and is not retried', () async {
      var sent = 0;
      await expectLater(
        NetGate.write((t) async {
          sent++;
          throw ApiFailure('Insufficient balance')..status = 422;
        }),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'message', 'Insufficient balance').having((e) => e.unconfirmed, 'unconfirmed', false)),
      );
      expect(sent, 1);
    });

    test('a connection error is a clear failure, not unconfirmed', () async {
      await expectLater(
        NetGate.write((t) async => throw Exception('socket')),
        throwsA(isA<ApiFailure>().having((e) => e.unconfirmed, 'unconfirmed', false).having((e) => e.message, 'm', NetGate.unreachableMessage)),
      );
    });

    test('a good answer is returned and marks DROP reachable', () async {
      conn.reportFailure(timeout: true);
      conn.reportFailure(timeout: true);
      expect(conn.status.value, NetStatus.degraded);
      final r = await NetGate.write((t) async => {'ok': true});
      expect(r['ok'], true);
      expect(conn.status.value, NetStatus.online);
    });
  });

  group('reads', () {
    test('identical reads in flight share one request', () async {
      var calls = 0;
      final gate = Completer<void>();
      Future<Map<String, dynamic>> run(Duration t) async {
        calls++;
        await gate.future;
        return {'n': calls};
      }

      final a = NetGate.read('k', run);
      final b = NetGate.read('k', run);
      gate.complete();
      expect((await a)['n'], 1);
      expect((await b)['n'], 1);
      expect(calls, 1);
      // finished, so the next one is a new request
      expect((await NetGate.read('k', (t) async => {'n': 2}))['n'], 2);
    });

    test('a network failure is retried with backoff, then succeeds', () async {
      var calls = 0;
      final r = await NetGate.read('r', (t) async {
        calls++;
        if (calls < 3) throw TimeoutException('slow');
        return {'ok': 1};
      });
      expect(r['ok'], 1);
      expect(calls, 3);
      expect(slept.length, 2);
      expect(slept[1] >= slept[0] ~/ 2, isTrue);
    });

    test('gives up after the retries instead of trying for ever', () async {
      var calls = 0;
      await expectLater(
        NetGate.read('g', (t) async {
          calls++;
          throw TimeoutException('slow');
        }),
        throwsA(isA<ApiFailure>().having((e) => e.timedOut, 'timedOut', true)),
      );
      expect(calls, 3); // the first try plus two retries
    });

    test('a 4xx answer is final: no retry', () async {
      var calls = 0;
      await expectLater(
        NetGate.read('x', (t) async {
          calls++;
          throw ApiFailure('Not found')..status = 404;
        }),
        throwsA(isA<ApiFailure>()),
      );
      expect(calls, 1);
    });

    test('a 503 from the gateway is retried once more', () async {
      var calls = 0;
      final r = await NetGate.read('s', (t) async {
        calls++;
        if (calls == 1) throw ApiFailure('Unavailable')..status = 503;
        return {'ok': 1};
      });
      expect(r['ok'], 1);
      expect(calls, 2);
    });

    test('offline: refused at once, no waiting for a timeout', () async {
      final offline = fakeConnectivity(linkUp: false);
      await offline.start();
      NetGate.connectivity = offline;
      var calls = 0;
      await expectLater(NetGate.read('o', (t) async {
        calls++;
        return {};
      }), throwsA(isA<ApiFailure>().having((e) => e.offline, 'offline', true)));
      expect(calls, 0);
    });
  });
}
