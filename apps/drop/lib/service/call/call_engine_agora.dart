import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'call_engine.dart';

/// Audio-only call through Agora.
class AgoraCallEngine implements CallEngine {
  final _events = StreamController<CallEngineEvent>.broadcast();
  RtcEngine? _engine;

  @override
  Stream<CallEngineEvent> get events => _events.stream;

  @override
  Future<void> join(CallJoin join) async {
    final engine = createAgoraRtcEngine();
    _engine = engine;
    try {
      await engine.initialize(RtcEngineContext(appId: join.appId ?? '', channelProfile: ChannelProfileType.channelProfileCommunication));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) => _events.add(CallEngineEvent.connected),
        onUserJoined: (connection, remoteUid, elapsed) => _events.add(CallEngineEvent.remoteJoined),
        onUserOffline: (connection, remoteUid, reason) => _events.add(CallEngineEvent.remoteLeft),
        onConnectionLost: (connection) => _events.add(CallEngineEvent.reconnecting),
        onRejoinChannelSuccess: (connection, elapsed) => _events.add(CallEngineEvent.reconnected),
        onError: (err, msg) => _events.add(CallEngineEvent.failed),
      ));
      await engine.enableAudio();
      await engine.setEnableSpeakerphone(false);
      await engine.joinChannel(
        token: join.token,
        channelId: join.room,
        uid: join.uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          publishCameraTrack: false,
          autoSubscribeVideo: false,
        ),
      );
    } catch (_) {
      _events.add(CallEngineEvent.failed);
      rethrow;
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  @override
  Future<void> setSpeaker(bool on) async {
    await _engine?.setEnableSpeakerphone(on);
  }

  @override
  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
  }
}
