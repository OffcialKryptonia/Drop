import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'call_engine.dart';

/// Audio-only call through LiveKit.
class LiveKitCallEngine implements CallEngine {
  final _events = StreamController<CallEngineEvent>.broadcast();
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  @override
  Stream<CallEngineEvent> get events => _events.stream;

  @override
  Future<void> join(CallJoin join) async {
    final room = Room(roomOptions: const RoomOptions(adaptiveStream: false, dynacast: false));
    _room = room;
    _listener = room.createListener()
      ..on<ParticipantConnectedEvent>((_) => _events.add(CallEngineEvent.remoteJoined))
      ..on<ParticipantDisconnectedEvent>((_) => _events.add(CallEngineEvent.remoteLeft))
      ..on<RoomReconnectingEvent>((_) => _events.add(CallEngineEvent.reconnecting))
      ..on<RoomReconnectedEvent>((_) => _events.add(CallEngineEvent.reconnected))
      ..on<RoomDisconnectedEvent>((_) => _events.add(CallEngineEvent.disconnected));
    try {
      await room.connect(join.url ?? '', join.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
    } catch (_) {
      _events.add(CallEngineEvent.failed);
      rethrow;
    }
    _events.add(CallEngineEvent.connected);
    if (room.remoteParticipants.isNotEmpty) _events.add(CallEngineEvent.remoteJoined);
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  @override
  Future<void> setSpeaker(bool on) async {
    await Hardware.instance.setSpeakerphoneOn(on);
  }

  @override
  Future<void> leave() async {
    final room = _room;
    _room = null;
    await _listener?.dispose();
    _listener = null;
    try {
      await room?.disconnect();
      await room?.dispose();
    } catch (_) {}
  }
}
