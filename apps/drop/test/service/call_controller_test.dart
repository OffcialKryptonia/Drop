import 'dart:async';

import 'package:drop/service/DriverApplicationApi.dart' show ApiFailure;
import 'package:drop/service/call/call_controller.dart';
import 'package:drop/service/call/call_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngine implements CallEngine {
  final _c = StreamController<CallEngineEvent>.broadcast();
  CallJoin? joined;
  bool left = false;
  bool? muted;
  bool? speaker;
  @override
  Stream<CallEngineEvent> get events => _c.stream;
  @override
  Future<void> join(CallJoin join) async {
    joined = join;
  }

  @override
  Future<void> setMuted(bool m) async => muted = m;
  @override
  Future<void> setSpeaker(bool on) async => speaker = on;
  @override
  Future<void> leave() async => left = true;
  void emit(CallEngineEvent e) => _c.add(e);
}

class FakeBackend implements CallBackend {
  String serverStatus = 'ringing';
  Map<String, dynamic>? incomingCall;
  ApiFailure? startFailure;
  final log = <String>[];

  Map<String, dynamic> _join(String uid) => {'provider': 'livekit', 'url': 'wss://x', 'token': 't', 'room': 'r', 'uid': uid};

  @override
  Future<Map<String, dynamic>> status(int rideId) async => {'data': {'can_call': true}};
  @override
  Future<Map<String, dynamic>> start(int rideId) async {
    log.add('start');
    if (startFailure != null) throw startFailure!;
    return {'data': {'call': {'id': 7}, 'join': _join('1')}};
  }

  @override
  Future<Map<String, dynamic>> incoming() async => {'data': incomingCall};
  @override
  Future<Map<String, dynamic>> get(int id) async => {'data': {'id': id, 'status': serverStatus}};
  @override
  Future<Map<String, dynamic>> accept(int id) async {
    log.add('accept');
    return {'data': {'call': {'id': id}, 'join': _join('2')}};
  }

  @override
  Future<Map<String, dynamic>> decline(int id) async {
    log.add('decline');
    return {};
  }

  @override
  Future<Map<String, dynamic>> cancel(int id) async {
    log.add('cancel');
    return {};
  }

  @override
  Future<Map<String, dynamic>> end(int id) async {
    log.add('end');
    return {};
  }

  @override
  Future<void> failed(int id) async => log.add('failed');
}

CallController make(FakeBackend b, FakeEngine e, {bool mic = true}) => CallController(
      backend: b,
      engineFactory: (_) => e,
      microphoneGranted: () async => mic,
      pollInterval: const Duration(milliseconds: 20),
      incomingInterval: const Duration(milliseconds: 20),
      endedLinger: const Duration(milliseconds: 30),
      remoteGoneAfter: const Duration(milliseconds: 40),
    );

Future<void> settle([int ms = 80]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('an outgoing call rings, becomes active when the other person joins, and can be ended', () async {
    final b = FakeBackend();
    final e = FakeEngine();
    final c = make(b, e);
    await c.start(5, 'Ada');
    expect(c.phase, CallPhase.outgoing);
    expect(e.joined?.room, 'r');
    e.emit(CallEngineEvent.remoteJoined);
    await settle();
    expect(c.phase, CallPhase.active);
    expect(c.activeSince, isNotNull);
    await c.toggleMute();
    await c.toggleSpeaker();
    expect(e.muted, true);
    expect(e.speaker, true);
    await c.end();
    expect(b.log, containsAll(['start', 'end']));
    expect(e.left, true);
    expect(c.phase, CallPhase.ended);
    await settle();
    expect(c.phase, CallPhase.idle);
  });

  test('cancelling while it rings tells the server to cancel, not end', () async {
    final b = FakeBackend();
    final c = make(b, FakeEngine());
    await c.start(5, 'Ada');
    await c.end();
    expect(b.log.contains('cancel'), true);
    expect(b.log.contains('end'), false);
  });

  test('an unanswered call shows as no answer when the server marks it missed', () async {
    final b = FakeBackend();
    final c = make(b, FakeEngine());
    await c.start(5, 'Ada');
    b.serverStatus = 'missed';
    await settle();
    expect(c.phase, CallPhase.ended);
    expect(c.note, 'No answer');
  });

  test('a declined call tells the caller it was declined', () async {
    final b = FakeBackend();
    final c = make(b, FakeEngine());
    await c.start(5, 'Ada');
    b.serverStatus = 'declined';
    await settle();
    expect(c.note, 'Call declined');
  });

  test('a refusal from the server (for example calling is off) ends the attempt with its message', () async {
    final b = FakeBackend()..startFailure = ApiFailure('In-app calling is not available right now.');
    final c = make(b, FakeEngine());
    await c.start(5, 'Ada');
    expect(c.phase, CallPhase.ended);
    expect(c.note, 'In-app calling is not available right now.');
  });

  test('without the microphone permission no call is placed', () async {
    final b = FakeBackend();
    final c = make(b, FakeEngine(), mic: false);
    await c.start(5, 'Ada');
    expect(b.log.contains('start'), false);
    expect(c.note, contains('microphone'));
  });

  test('an incoming call is picked up, can be answered and then joins the room', () async {
    final b = FakeBackend()..incomingCall = {'id': 9, 'ride_id': 5, 'status': 'ringing', 'caller_name': 'Ada Obi'};
    final e = FakeEngine();
    final c = make(b, e);
    var shown = 0;
    c.presenter = () => shown++;
    await c.checkIncoming();
    expect(c.phase, CallPhase.incoming);
    expect(c.peerName, 'Ada Obi');
    expect(shown, 1);
    await c.accept();
    expect(b.log.contains('accept'), true);
    e.emit(CallEngineEvent.connected);
    await settle();
    expect(c.phase, CallPhase.active);
    expect(e.joined?.uid, 2);
    b.serverStatus = 'ended'; // the other person hangs up
    await settle();
    expect(c.phase, CallPhase.ended);
    expect(e.left, true);
  });

  test('declining an incoming call tells the server and never opens the audio session', () async {
    final b = FakeBackend()..incomingCall = {'id': 9, 'ride_id': 5, 'status': 'ringing', 'caller_name': 'Ada'};
    final e = FakeEngine();
    final c = make(b, e);
    await c.checkIncoming();
    await c.decline();
    expect(b.log, ['decline']);
    expect(e.joined, isNull);
  });

  test('an incoming call that the caller cancels becomes a missed call', () async {
    final b = FakeBackend()..incomingCall = {'id': 9, 'ride_id': 5, 'status': 'ringing', 'caller_name': 'Ada'};
    final c = make(b, FakeEngine());
    await c.checkIncoming();
    b.serverStatus = 'cancelled';
    await settle();
    expect(c.note, 'Missed call');
  });

  test('a second incoming call is ignored while one is already in progress', () async {
    final b = FakeBackend()..incomingCall = {'id': 9, 'ride_id': 5, 'status': 'ringing', 'caller_name': 'Ada'};
    final c = make(b, FakeEngine());
    await c.start(5, 'Ada');
    b.incomingCall = {'id': 10, 'ride_id': 5, 'status': 'ringing', 'caller_name': 'Other'};
    await c.checkIncoming();
    expect(c.callId, 7);
  });

  test('if the other person drops out of the room for too long the call ends', () async {
    final b = FakeBackend();
    final e = FakeEngine();
    final c = make(b, e);
    await c.start(5, 'Ada');
    e.emit(CallEngineEvent.remoteJoined);
    await settle(30);
    e.emit(CallEngineEvent.remoteLeft);
    await settle(150);
    expect(c.phase == CallPhase.ended || c.phase == CallPhase.idle, true);
  });

  test('an audio connection failure ends the call and is reported to the server', () async {
    final b = FakeBackend();
    final e = FakeEngine();
    final c = make(b, e);
    await c.start(5, 'Ada');
    e.emit(CallEngineEvent.failed);
    await settle();
    expect(b.log.contains('failed'), true);
    expect(c.note, 'Could not connect the call.');
  });
}
