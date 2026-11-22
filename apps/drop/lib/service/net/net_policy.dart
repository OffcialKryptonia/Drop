import 'dart:async';
import 'dart:math' as math;

import '../DriverApplicationApi.dart' show ApiFailure;
import 'connectivity_service.dart';

/// Exponential backoff with jitter: 0.4 s, 0.8 s, 1.6 s ... each randomised so many phones do not retry in step.
class Backoff {
  Backoff({this.base = const Duration(milliseconds: 400), this.cap = const Duration(seconds: 6), math.Random? random}) : _random = random ?? math.Random();

  final Duration base;
  final Duration cap;
  final math.Random _random;

  Duration delay(int attempt) {
    final ceiling = math.min(cap.inMilliseconds, base.inMilliseconds * (1 << attempt.clamp(0, 10)));
    final ms = (ceiling / 2) + _random.nextInt((ceiling / 2).round() + 1);
    return Duration(milliseconds: ms.round());
  }
}

/// Every call to DROP's server goes through here, so the rules live in one place:
///
/// * **Reads** are shared (two screens asking for the same thing make one request), time out in 12 s,
///   and are retried twice with backoff when the network (not the server) fails.
/// * **Writes** are never retried and never queued. Offline they are refused at once with a clear message.
///   If one times out after it was sent, the failure says the result is *unconfirmed*, so the screen can
///   check the real status instead of guessing or sending it twice.
class NetGate {
  NetGate._();

  static ConnectivityService connectivity = ConnectivityService.instance;
  static Backoff backoff = Backoff();
  static Future<void> Function(Duration) sleep = (d) => Future<void>.delayed(d);

  static const offlineMessage = 'You are offline. Connect to the internet and try again.';
  static const unreachableMessage = 'Could not reach DROP. Check your internet connection and try again.';
  static const unconfirmedMessage = 'We could not confirm whether that went through. Check your current ride or history before trying again.';

  static final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  static Future<Map<String, dynamic>> read(
    String key,
    Future<Map<String, dynamic>> Function(Duration timeout) run, {
    int retries = 2,
    Duration timeout = const Duration(seconds: 12),
  }) {
    if (connectivity.isOffline) return Future.error(ApiFailure(offlineMessage)..offline = true);
    final shared = _inFlight[key];
    if (shared != null) return shared;
    final f = _readWithRetry(run, retries, timeout).whenComplete(() => _inFlight.remove(key));
    _inFlight[key] = f;
    return f;
  }

  static Future<Map<String, dynamic>> _readWithRetry(Future<Map<String, dynamic>> Function(Duration) run, int retries, Duration timeout) async {
    for (var attempt = 0;; attempt++) {
      try {
        final r = await run(timeout);
        connectivity.reportSuccess();
        return r;
      } on ApiFailure catch (e) {
        if (!e.retriable || attempt >= retries) {
          if (!e.retriable) connectivity.reportSuccess(); // the server answered, even if it said no
          throw e;
        }
      } on TimeoutException {
        connectivity.reportFailure(timeout: true);
        if (attempt >= retries) throw ApiFailure(unreachableMessage)..timedOut = true;
      } catch (_) {
        connectivity.reportFailure(timeout: false);
        if (attempt >= retries) throw ApiFailure(unreachableMessage);
      }
      if (connectivity.isOffline) throw ApiFailure(offlineMessage)..offline = true;
      await sleep(backoff.delay(attempt));
    }
  }

  static Future<Map<String, dynamic>> write(
    Future<Map<String, dynamic>> Function(Duration timeout) run, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (connectivity.isOffline) throw ApiFailure(offlineMessage)..offline = true;
    try {
      final r = await run(timeout);
      connectivity.reportSuccess();
      return r;
    } on ApiFailure catch (e) {
      if (!e.retriable) connectivity.reportSuccess();
      rethrow;
    } on TimeoutException {
      connectivity.reportFailure(timeout: true);
      // The request may have reached the server. Never claim it failed, and never resend on our own.
      throw ApiFailure(unconfirmedMessage)
        ..unconfirmed = true
        ..timedOut = true;
    } catch (_) {
      connectivity.reportFailure(timeout: false);
      throw ApiFailure(unreachableMessage);
    }
  }
}
