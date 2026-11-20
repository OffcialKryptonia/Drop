import 'dart:async';

import 'call_engine_agora.dart';
import 'call_engine_livekit.dart';

/// What the server hands out to join a call. Only a short-lived token for this person and this room;
/// the provider secret never reaches the app.
class CallJoin {
  const CallJoin({required this.provider, required this.token, required this.room, required this.uid, this.url, this.appId});

  factory CallJoin.fromJson(Map<String, dynamic> j) => CallJoin(
        provider: '${j['provider']}',
        token: '${j['token']}',
        room: '${j['room']}',
        uid: j['uid'] is num ? (j['uid'] as num).toInt() : int.tryParse('${j['uid']}') ?? 0,
        url: j['url']?.toString(),
        appId: j['app_id']?.toString(),
      );

  final String provider; // 'livekit' | 'agora'
  final String token;
  final String room;
  final int uid;
  final String? url; // LiveKit server address
  final String? appId; // Agora app id
}

enum CallEngineEvent { connected, remoteJoined, remoteLeft, disconnected, reconnecting, reconnected, failed }

/// One interface for both calling providers, so the rest of the app never knows which one is in use.
abstract class CallEngine {
  Stream<CallEngineEvent> get events;
  Future<void> join(CallJoin join);
  Future<void> setMuted(bool muted);
  Future<void> setSpeaker(bool on);
  Future<void> leave();

  static CallEngine forProvider(String provider) => provider == 'agora' ? AgoraCallEngine() : LiveKitCallEngine();
}
