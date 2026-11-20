import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../DriverApplicationApi.dart' show ApiFailure;
import '../RideApi.dart';
import 'call_engine.dart';

/// The server side of a call. A thin wrapper so the controller can be tested without a network.
abstract class CallBackend {
  Future<Map<String, dynamic>> status(int rideId);
  Future<Map<String, dynamic>> start(int rideId);
  Future<Map<String, dynamic>> incoming();
  Future<Map<String, dynamic>> get(int callId);
  Future<Map<String, dynamic>> accept(int callId);
  Future<Map<String, dynamic>> decline(int callId);
  Future<Map<String, dynamic>> cancel(int callId);
  Future<Map<String, dynamic>> end(int callId);
  Future<void> failed(int callId);
}

class RideCallBackend implements CallBackend {
  const RideCallBackend();
  @override
  Future<Map<String, dynamic>> status(int rideId) => RideApi.callStatus(rideId);
  @override
  Future<Map<String, dynamic>> start(int rideId) => RideApi.startCall(rideId);
  @override
  Future<Map<String, dynamic>> incoming() => RideApi.incomingCall();
  @override
  Future<Map<String, dynamic>> get(int callId) => RideApi.getCall(callId);
  @override
  Future<Map<String, dynamic>> accept(int callId) => RideApi.acceptCall(callId);
  @override
  Future<Map<String, dynamic>> decline(int callId) => RideApi.declineCall(callId);
  @override
  Future<Map<String, dynamic>> cancel(int callId) => RideApi.cancelCall(callId);
  @override
  Future<Map<String, dynamic>> end(int callId) => RideApi.endCall(callId);
  @override
  Future<void> failed(int callId) async {
    await RideApi.callFailed(callId);
  }
}

enum CallPhase { idle, outgoing, incoming, connecting, active, ended }

/// Runs one voice call at a time: ringing, answering, the audio session, mute/speaker, and hanging up.
/// The server decides who may call whom; this class only follows what the server says.
class CallController extends ChangeNotifier {
  CallController({
    CallBackend backend = const RideCallBackend(),
    CallEngine Function(String provider)? engineFactory,
    Future<bool> Function()? microphoneGranted,
    this.pollInterval = const Duration(seconds: 2),
    this.incomingInterval = const Duration(seconds: 3),
    this.endedLinger = const Duration(seconds: 2),
    this.remoteGoneAfter = const Duration(seconds: 8),
  })  : _backend = backend,
        _engineFactory = engineFactory ?? CallEngine.forProvider,
        _mic = microphoneGranted ?? _askMicrophone;

  static final CallController instance = CallController();

  final CallBackend _backend;
  final CallEngine Function(String) _engineFactory;
  final Future<bool> Function() _mic;
  final Duration pollInterval;
  final Duration incomingInterval;
  final Duration endedLinger;
  final Duration remoteGoneAfter;

  static Future<bool> _askMicrophone() async => (await Permission.microphone.request()).isGranted;

  CallPhase phase = CallPhase.idle;
  int? callId;
  int? rideId;
  String peerName = '';
  String? note; // why the call ended, shown briefly
  bool muted = false;
  bool speaker = false;
  bool reconnecting = false;
  DateTime? activeSince;

  CallEngine? _engine;
  StreamSubscription<CallEngineEvent>? _engineSub;
  Timer? _poll;
  Timer? _incomingTimer;
  Timer? _goneTimer;
  Timer? _lingerTimer;
  int _watchers = 0;
  bool _busy = false;

  /// Called when a call needs the full-screen call page (set by whoever has a navigator).
  VoidCallback? presenter;

  bool get inCall => phase != CallPhase.idle;

  Duration get elapsed => activeSince == null ? Duration.zero : DateTime.now().difference(activeSince!);

  void _set(CallPhase p, {String? why}) {
    phase = p;
    if (why != null) note = why;
    notifyListeners();
  }

  // ---------------------------------------------------------------- availability

  /// Whether this ride shows a call button: the server says (calling on, provider set up, trip open).
  Future<bool> available(int rideId) async {
    try {
      final r = await _backend.status(rideId);
      return (r['data'] as Map?)?['can_call'] == true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- watching for incoming calls

  /// While a trip screen is open, ask the server every few seconds whether someone is calling.
  void watch() {
    _watchers++;
    _incomingTimer ??= Timer.periodic(incomingInterval, (_) => checkIncoming());
    checkIncoming();
  }

  void unwatch() {
    if (_watchers > 0) _watchers--;
    if (_watchers == 0) {
      _incomingTimer?.cancel();
      _incomingTimer = null;
    }
  }

  Future<void> checkIncoming() async {
    if (phase != CallPhase.idle || _busy) return;
    try {
      final r = await _backend.incoming();
      final d = r['data'];
      if (d is! Map || phase != CallPhase.idle) return;
      callId = (d['id'] as num).toInt();
      rideId = (d['ride_id'] as num).toInt();
      peerName = (d['caller_name'] ?? 'Drop').toString();
      muted = false;
      speaker = false;
      note = null;
      _set(CallPhase.incoming);
      _startPolling();
      presenter?.call();
    } catch (_) {
      // Not signed in, offline: nothing is ringing as far as we can tell.
    }
  }

  // ---------------------------------------------------------------- the person calls

  Future<void> start(int ride, String name) async {
    if (inCall) return;
    _busy = true;
    _lingerTimer?.cancel();
    rideId = ride;
    peerName = name;
    muted = false;
    speaker = false;
    note = null;
    activeSince = null;
    callId = null;
    _set(CallPhase.outgoing);
    presenter?.call();
    try {
      if (!await _mic()) return _finish('Allow the microphone in Settings to make calls.', tellServer: false);
      final r = await _backend.start(ride);
      final data = Map<String, dynamic>.from(r['data'] as Map);
      callId = ((data['call'] as Map)['id'] as num).toInt();
      final join = CallJoin.fromJson(Map<String, dynamic>.from(data['join'] as Map));
      _startPolling();
      await _joinEngine(join);
    } on ApiFailure catch (e) {
      await _finish(e.message, tellServer: false);
    } catch (_) {
      await _finish('Could not start the call. Please try again.');
    } finally {
      _busy = false;
    }
  }

  // ---------------------------------------------------------------- the person answers

  Future<void> accept() async {
    final id = callId;
    if (phase != CallPhase.incoming || id == null) return;
    _busy = true;
    _set(CallPhase.connecting);
    try {
      if (!await _mic()) {
        await _backend.decline(id).catchError((_) => <String, dynamic>{});
        return _finish('Allow the microphone in Settings to answer calls.', tellServer: false);
      }
      final r = await _backend.accept(id);
      final join = CallJoin.fromJson(Map<String, dynamic>.from((r['data'] as Map)['join'] as Map));
      await _joinEngine(join);
    } on ApiFailure catch (e) {
      await _finish(e.message, tellServer: false);
    } catch (_) {
      await _finish('Could not connect the call.');
    } finally {
      _busy = false;
    }
  }

  Future<void> decline() async {
    final id = callId;
    if (phase != CallPhase.incoming || id == null) return;
    try {
      await _backend.decline(id);
    } catch (_) {}
    await _finish('Call declined', tellServer: false);
  }

  /// Hang up (or cancel while it is still ringing).
  Future<void> end() async {
    final id = callId;
    if (!inCall || id == null) return;
    final ringing = phase == CallPhase.outgoing;
    try {
      await (ringing ? _backend.cancel(id) : _backend.end(id));
    } catch (_) {}
    await _finish(ringing ? 'Call cancelled' : 'Call ended', tellServer: false);
  }

  // ---------------------------------------------------------------- in the call

  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
    await _engine?.setMuted(muted).catchError((_) {});
  }

  Future<void> toggleSpeaker() async {
    speaker = !speaker;
    notifyListeners();
    await _engine?.setSpeaker(speaker).catchError((_) {});
  }

  Future<void> _joinEngine(CallJoin join) async {
    final engine = _engineFactory(join.provider);
    _engine = engine;
    _engineSub = engine.events.listen(_onEngine);
    await engine.join(join);
  }

  void _onEngine(CallEngineEvent e) {
    switch (e) {
      case CallEngineEvent.remoteJoined:
        _goneTimer?.cancel();
        _goneTimer = null;
        if (phase == CallPhase.outgoing || phase == CallPhase.connecting) _becomeActive();
        break;
      case CallEngineEvent.connected:
        // The callee is already answering, so being connected means we are in the call.
        if (phase == CallPhase.connecting) _becomeActive();
        break;
      case CallEngineEvent.reconnecting:
        reconnecting = true;
        notifyListeners();
        break;
      case CallEngineEvent.reconnected:
        reconnecting = false;
        notifyListeners();
        break;
      case CallEngineEvent.remoteLeft:
        if (phase == CallPhase.active) {
          _goneTimer?.cancel();
          _goneTimer = Timer(remoteGoneAfter, () => end());
        }
        break;
      case CallEngineEvent.disconnected:
        break; // the server poll decides whether the call is really over
      case CallEngineEvent.failed:
        if (inCall) _finish('Could not connect the call.');
        break;
    }
  }

  void _becomeActive() {
    activeSince ??= DateTime.now();
    reconnecting = false;
    _set(CallPhase.active);
  }

  // ---------------------------------------------------------------- following the server

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    final id = callId;
    if (id == null || !inCall) return;
    try {
      final d = (await _backend.get(id))['data'] as Map?;
      if (d == null || callId != id) return;
      final status = '${d['status']}';
      if (status == 'ringing') return;
      if (status == 'active') {
        // The other person answered; we are the caller and already in the room.
        if (phase == CallPhase.outgoing) _becomeActive();
        return;
      }
      const why = {
        'declined': 'Call declined',
        'missed': 'No answer',
        'cancelled': 'Call cancelled',
        'ended': 'Call ended',
        'failed': 'Call failed',
      };
      final missedIncoming = phase == CallPhase.incoming && (status == 'missed' || status == 'cancelled');
      await _finish(missedIncoming ? 'Missed call' : (why[status] ?? 'Call ended'), tellServer: false);
    } catch (_) {
      // A dropped request is not the end of the call; the next poll tries again.
    }
  }

  // ---------------------------------------------------------------- closing

  Future<void> _finish(String why, {bool tellServer = true}) async {
    final id = callId;
    _poll?.cancel();
    _poll = null;
    _goneTimer?.cancel();
    _goneTimer = null;
    await _engineSub?.cancel();
    _engineSub = null;
    final engine = _engine;
    _engine = null;
    try {
      await engine?.leave();
    } catch (_) {}
    if (tellServer && id != null && why.startsWith('Could not connect')) {
      try {
        await _backend.failed(id);
      } catch (_) {}
    }
    reconnecting = false;
    _set(CallPhase.ended, why: why);
    _lingerTimer?.cancel();
    _lingerTimer = Timer(endedLinger, () {
      if (phase == CallPhase.ended) {
        callId = null;
        activeSince = null;
        _set(CallPhase.idle);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _incomingTimer?.cancel();
    _goneTimer?.cancel();
    _lingerTimer?.cancel();
    _engineSub?.cancel();
    super.dispose();
  }
}
