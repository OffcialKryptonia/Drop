import 'package:drop/drop/screens/drop_call_screen.dart';
import 'package:drop/service/call/call_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Backend implements CallBackend {
  @override
  Future<Map<String, dynamic>> status(int rideId) async => {'data': {'can_call': true}};
  @override
  Future<Map<String, dynamic>> start(int rideId) async => {};
  @override
  Future<Map<String, dynamic>> incoming() async => {'data': null};
  @override
  Future<Map<String, dynamic>> get(int callId) async => {'data': {'status': 'ringing'}};
  @override
  Future<Map<String, dynamic>> accept(int callId) async => {};
  @override
  Future<Map<String, dynamic>> decline(int callId) async => {};
  @override
  Future<Map<String, dynamic>> cancel(int callId) async => {};
  @override
  Future<Map<String, dynamic>> end(int callId) async => {};
  @override
  Future<void> failed(int callId) async {}
}

void main() {
  test('call clock formats minutes and hours', () {
    expect(dropCallClock(const Duration(seconds: 5)), '00:05');
    expect(dropCallClock(const Duration(minutes: 3, seconds: 42)), '03:42');
    expect(dropCallClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  testWidgets('an incoming call offers Answer and Decline and shows the caller', (tester) async {
    final c = CallController(backend: _Backend())
      ..phase = CallPhase.incoming
      ..peerName = 'Ada Obi'
      ..callId = 3;
    await tester.pumpWidget(MaterialApp(home: DropCallScreen(controller: c)));
    expect(find.text('Ada Obi'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('End call'), findsNothing);
  });

  testWidgets('an outgoing call shows Calling and a single End call button', (tester) async {
    final c = CallController(backend: _Backend())
      ..phase = CallPhase.outgoing
      ..peerName = 'Ada Obi'
      ..callId = 3;
    await tester.pumpWidget(MaterialApp(home: DropCallScreen(controller: c)));
    expect(find.text('Calling…'), findsOneWidget);
    expect(find.text('End call'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);
  });

  testWidgets('an active call shows the timer, mute and speaker', (tester) async {
    final c = CallController(backend: _Backend())
      ..phase = CallPhase.active
      ..peerName = 'Ada Obi'
      ..callId = 3
      ..activeSince = DateTime.now().subtract(const Duration(seconds: 65));
    await tester.pumpWidget(MaterialApp(home: DropCallScreen(controller: c)));
    expect(find.textContaining('01:0'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    expect(c.muted, true);
    expect(find.text('Unmute'), findsOneWidget);
  });

  testWidgets('a finished call shows why it ended and no buttons', (tester) async {
    final c = CallController(backend: _Backend())
      ..phase = CallPhase.ended
      ..note = 'No answer'
      ..peerName = 'Ada Obi';
    await tester.pumpWidget(MaterialApp(home: DropCallScreen(controller: c)));
    expect(find.text('No answer'), findsOneWidget);
    expect(find.text('End call'), findsNothing);
  });
}
