import 'package:drop/drop/widgets/drop_ride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DropStopTimeline', () {
    testWidgets('shows pickup, ordered intermediate stops and drop-off', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DropStopTimeline(
            pickup: 'Pickup address',
            dropoff: 'Final destination',
            stops: [
              {'id': 2, 'sequence': 2, 'address': 'Second stop', 'status': 'pending'},
              {'id': 1, 'sequence': 1, 'address': 'First stop', 'status': 'completed'},
            ],
          ),
        ),
      ));

      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('STOP 1'), findsOneWidget);
      expect(find.text('First stop'), findsOneWidget);
      expect(find.text('STOP 2'), findsOneWidget);
      expect(find.text('Second stop'), findsOneWidget);
      expect(find.text('DROP-OFF'), findsOneWidget);
    });

    testWidgets('keeps the direct-trip pickup-to-drop-off timeline', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DropStopTimeline(
            pickup: 'Pickup address',
            dropoff: 'Final destination',
          ),
        ),
      ));

      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('DROP-OFF'), findsOneWidget);
      expect(find.textContaining('STOP'), findsNothing);
    });
  });
}
