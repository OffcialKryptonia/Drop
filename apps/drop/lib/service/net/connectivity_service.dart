import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../utils/Constants.dart';

/// What DROP knows about reaching its own server. The device having Wi-Fi or mobile data is not enough:
/// a phone can be on Wi-Fi with no internet, or online while DROP's backend is down.
enum NetStatus {
  /// DROP's server answers.
  online,

  /// No network on the device at all (airplane mode, no signal). Writes are refused right away.
  offline,

  /// A network exists but requests keep timing out.
  degraded,

  /// The network came back and we are checking that DROP answers.
  reconnecting,

  /// The device is connected, but DROP's server did not answer the health check.
  serverDown,
}

/// The one place that decides "are we online". Widgets and API clients ask this service; nothing else
/// should call `Connectivity()` directly. It combines the device link with a light backend health check
/// and the outcome of real requests. It never polls while everything works, and probes back off when it does not.
class ConnectivityService {
  ConnectivityService({
    Stream<bool>? linkChanges,
    Future<bool> Function()? checkLink,
    Future<bool> Function()? probe,
    Duration Function(int attempt)? retryDelay,
    Duration minProbeGap = const Duration(seconds: 10),
    DateTime Function()? now,
  })  : _linkChanges = linkChanges,
        _checkLink = checkLink ?? _deviceHasLink,
        _probe = probe ?? _healthProbe,
        _retryDelay = retryDelay ?? defaultRetryDelay,
        _minProbeGap = minProbeGap,
        _now = now ?? DateTime.now;

  static final ConnectivityService instance = ConnectivityService();

  /// 5 s, 10 s, 20 s, 40 s, then every 60 s: patient, never a hammer.
  static Duration defaultRetryDelay(int attempt) {
    final seconds = 5 * (1 << attempt.clamp(0, 4));
    return Duration(seconds: seconds > 60 ? 60 : seconds);
  }

  final Stream<bool>? _linkChanges;
  final Future<bool> Function() _checkLink;
  final Future<bool> Function() _probe;
  final Duration Function(int attempt) _retryDelay;
  final Duration _minProbeGap;
  final DateTime Function() _now;

  final ValueNotifier<NetStatus> status = ValueNotifier<NetStatus>(NetStatus.online);

  /// Counts up each time we go from a bad state back to [NetStatus.online]. The banner uses it to say "You're back online."
  final ValueNotifier<int> recoveries = ValueNotifier<int>(0);

  StreamSubscription<bool>? _sub;
  Timer? _retry;
  int _attempt = 0;
  int _timeouts = 0;
  int _failures = 0;
  DateTime? _lastProbe;
  bool _probing = false;
  bool _started = false;

  bool get isOffline => status.value == NetStatus.offline;
  bool get isOnline => status.value == NetStatus.online;

  /// Starts listening. Call it after the first frame, never before: it must not delay the interface.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = (_linkChanges ?? _deviceLinkStream()).listen(_onLink);
    final up = await _checkLink();
    if (!up) _set(NetStatus.offline);
  }

  void dispose() {
    _sub?.cancel();
    _retry?.cancel();
  }

  void _set(NetStatus next) {
    final before = status.value;
    if (before == next) return;
    status.value = next;
    if (next == NetStatus.online && before != NetStatus.online) recoveries.value++;
  }

  void _onLink(bool up) {
    if (!up) {
      _retry?.cancel();
      _set(NetStatus.offline);
      return;
    }
    if (status.value == NetStatus.offline) {
      _set(NetStatus.reconnecting);
      _attempt = 0;
      probeNow(force: true);
    }
  }

  /// A real request worked, so we are online whatever the last check said.
  void reportSuccess() {
    _timeouts = 0;
    _failures = 0;
    _retry?.cancel();
    _attempt = 0;
    if (status.value != NetStatus.online) _set(NetStatus.online);
  }

  /// A real request did not get through. A few timeouts in a row mean the connection is weak;
  /// a few other failures mean it is worth asking the server directly.
  void reportFailure({required bool timeout}) {
    if (status.value == NetStatus.offline) return;
    if (timeout) {
      _timeouts++;
      if (_timeouts >= 2 && status.value == NetStatus.online) _set(NetStatus.degraded);
    }
    _failures++;
    if (_failures >= 2) probeNow();
  }

  /// Asks DROP's health endpoint. Rate limited, so a burst of failures makes one check, not many.
  Future<void> probeNow({bool force = false}) async {
    if (_probing) return;
    final last = _lastProbe;
    if (!force && last != null && _now().difference(last) < _minProbeGap) return;
    _probing = true;
    _lastProbe = _now();
    try {
      if (!await _checkLink()) {
        _set(NetStatus.offline);
        return;
      }
      final ok = await _probe();
      if (ok) {
        _failures = 0;
        _timeouts = 0;
        _attempt = 0;
        _retry?.cancel();
        _set(NetStatus.online);
      } else {
        _set(NetStatus.serverDown);
        _scheduleRetry();
      }
    } catch (_) {
      _set(NetStatus.serverDown);
      _scheduleRetry();
    } finally {
      _probing = false;
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    final delay = _retryDelay(_attempt++);
    _retry = Timer(delay, () => probeNow(force: true));
  }

  /// The app came back to the foreground: if it was not fully online, check again now.
  void onResume() {
    if (!_started) return;
    if (status.value != NetStatus.online) {
      _attempt = 0;
      probeNow(force: true);
    }
  }

  static Future<bool> _deviceHasLink() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  static Stream<bool> _deviceLinkStream() => Connectivity().onConnectivityChanged.map((r) => !r.contains(ConnectivityResult.none)).distinct();

  static Future<bool> _healthProbe() async {
    try {
      final r = await http.get(Uri.parse('$DOMAIN_URL/api/health')).timeout(const Duration(seconds: 5));
      return r.statusCode >= 200 && r.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
