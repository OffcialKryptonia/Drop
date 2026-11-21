import 'package:drop/drop/screens/drop_bid_screen.dart';
import 'package:drop/drop/widgets/drop_bid_ui.dart';
import 'package:drop/service/DriverApplicationApi.dart' show ApiFailure;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

Map<String, dynamic> response({int id = 1, String status = 'driver_accepted_offer', num amount = 4500, bool selectable = true, bool canAccept = false, bool canRevise = false, String? waitingOn}) => {
      'id': id,
      'status': status,
      'amount': amount,
      'rounds': 1,
      'rounds_left': 2,
      'selectable': selectable,
      'can_accept': canAccept,
      'can_reject': true,
      'can_revise': canRevise,
      'waiting_on': waitingOn,
      'driver': {
        'id': 7,
        'name': 'Musa Ibrahim',
        'profile_image': null,
        'rating': 4.8,
        'rating_count': 120,
        'completed_rides': 340,
        'vehicle': {'type': 'Car', 'make': 'Toyota', 'model': 'Corolla', 'colour': 'Silver', 'plate': 'ABJ-123-XY'},
        'distance_km': 1.4,
        'eta_minutes': 4,
      },
    };

Map<String, dynamic> bidMap({String status = 'open', List<Map<String, dynamic>> responses = const [], bool canRevise = true, int declined = 0}) => {
      'id': 5,
      'status': status,
      'currency': {'code': 'NGN', 'symbol': '₦'},
      'estimate_fare': 5500,
      'offer_fare': 4500,
      'limits': {'min': 3850, 'max': 8250},
      'max_rounds': 3,
      'rounds_used': 0,
      'can_revise': canRevise,
      'seconds_left': 150,
      'expires_at': DateTime.now().add(const Duration(seconds: 150)).toUtc().toIso8601String(),
      'distance': 8.2,
      'distance_unit': 'km',
      'duration_minutes': 19,
      'payment_method': 'cash',
      'pickup': {'address': 'Wuse Market, Abuja'},
      'dropoff': {'address': 'Gwarinpa Estate, Abuja'},
      'stops': [
        {'address': 'Jabi Lake Mall'}
      ],
      'declined_count': declined,
      'responses': responses,
    };

class FakeBackend implements PassengerBidBackend {
  FakeBackend(this.bid);
  Map<String, dynamic> bid;
  bool fail = false;
  final calls = <String>[];
  Map<String, dynamic>? selectResult;
  ApiFailure? selectFailure;

  @override
  Future<Map<String, dynamic>> get(int id) async {
    if (fail) throw ApiFailure('no network');
    return {'status': true, 'data': bid};
  }

  @override
  Future<Map<String, dynamic>> cancel(int id) async {
    calls.add('cancel');
    return {'status': true, 'data': {...bid, 'status': 'cancelled'}};
  }

  @override
  Future<Map<String, dynamic>> revise(int id, num offer) async {
    calls.add('revise $offer');
    return {'status': true, 'data': bid};
  }

  @override
  Future<Map<String, dynamic>> acceptCounter(int bidId, int responseId) async {
    calls.add('accept $responseId');
    return {'status': true, 'data': bid};
  }

  @override
  Future<Map<String, dynamic>> rejectResponse(int bidId, int responseId) async {
    calls.add('reject $responseId');
    return {'status': true, 'data': bid};
  }

  @override
  Future<Map<String, dynamic>> reviseResponse(int bidId, int responseId, num amount) async {
    calls.add('counter $responseId $amount');
    return {'status': true, 'data': bid};
  }

  @override
  Future<Map<String, dynamic>> select(int bidId, int responseId) async {
    calls.add('select $responseId');
    if (selectFailure != null) throw selectFailure!;
    return {'status': true, 'data': selectResult ?? {...bid, 'status': 'confirmed'}};
  }
}

/// Opens the bid screen on top of a plain page so its outcome can be read.
Future<Future<DropBidOutcome?> Function()> launch(WidgetTester tester, FakeBackend be, {Duration poll = const Duration(seconds: 30)}) async {
  DropBidOutcome? result;
  var done = false;
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<DropBidOutcome>(context, MaterialPageRoute(builder: (_) => DropBidScreen(bidId: 5, initial: be.bid, backend: be, pollEvery: poll)));
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  return () async {
    await tester.pump();
    expect(done, isTrue);
    return result;
  };
}

void main() {
  group('fare editor', () {
    testWidgets('shows the amount and the allowed range, and steps within it', (t) async {
      var v = 4500.0;
      await t.pumpWidget(StatefulBuilder(builder: (c, set) => wrap(DropFareEditor(amount: v, min: 3850, max: 8250, reference: 5500, onChanged: (x) => set(() => v = x)))));
      expect(find.text('₦4,500'), findsOneWidget);
      expect(find.textContaining('₦3,850 to ₦8,250', findRichText: true), findsOneWidget);
      expect(find.textContaining('DROP estimate ₦5,500', findRichText: true), findsOneWidget);
      await t.tap(find.byIcon(Icons.add));
      await t.pump();
      expect(v, 4600);
      await t.tap(find.byIcon(Icons.remove));
      await t.pump();
      await t.tap(find.byIcon(Icons.remove));
      await t.pump();
      expect(v, 4400);
    });

    testWidgets('cannot go outside the range', (t) async {
      var v = 3850.0;
      await t.pumpWidget(StatefulBuilder(builder: (c, set) => wrap(DropFareEditor(amount: v, min: 3850, max: 8250, onChanged: (x) => set(() => v = x)))));
      await t.tap(find.byIcon(Icons.remove));
      await t.pump();
      expect(v, 3850);
      v = 8250;
      await t.pumpWidget(StatefulBuilder(builder: (c, set) => wrap(DropFareEditor(amount: v, min: 3850, max: 8250, onChanged: (x) => set(() => v = x)))));
      await t.tap(find.byIcon(Icons.add));
      await t.pump();
      expect(v, 8250);
    });

    testWidgets('a typed amount is clamped into the range', (t) async {
      var v = 4500.0;
      await t.pumpWidget(StatefulBuilder(builder: (c, set) => wrap(DropFareEditor(amount: v, min: 3850, max: 8250, onChanged: (x) => set(() => v = x)))));
      await t.tap(find.byKey(const Key('fare_amount')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '999999');
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(v, 8250);
    });

    test('step grows with the fare', () {
      expect(dropFareStep(1500), 50);
      expect(dropFareStep(5500), 100);
      expect(dropFareStep(15000), 250);
      expect(dropFareStep(60000), 500);
    });
  });

  group('driver response card', () {
    testWidgets('an agreed driver shows who they are and can be chosen', (t) async {
      var chosen = 0;
      await t.pumpWidget(wrap(DropBidResponseCard(response: response(), symbol: '₦', busy: false, onSelect: () => chosen++, onAccept: () {}, onReject: () {}, onCounter: () {})));
      expect(find.text('Musa Ibrahim'), findsOneWidget);
      expect(find.text('4.8 (120)'), findsOneWidget);
      expect(find.textContaining('340 trips'), findsOneWidget);
      expect(find.textContaining('Silver Toyota Corolla · ABJ-123-XY'), findsOneWidget);
      expect(find.textContaining('1.4 km · 4 min away'), findsOneWidget);
      expect(find.text('₦4,500'), findsOneWidget);
      expect(find.text('Accepted your offer'), findsOneWidget);
      await t.tap(find.textContaining('Choose Musa'));
      expect(chosen, 1);
    });

    testWidgets('a counteroffer can be accepted, rejected or answered with a different offer', (t) async {
      final log = <String>[];
      await t.pumpWidget(wrap(DropBidResponseCard(
        response: response(status: 'counteroffered', amount: 5000, selectable: false, canAccept: true, canRevise: true),
        symbol: '₦',
        busy: false,
        onSelect: () => log.add('select'),
        onAccept: () => log.add('accept'),
        onReject: () => log.add('reject'),
        onCounter: () => log.add('counter'),
      )));
      expect(find.text('Counteroffer'), findsOneWidget);
      expect(find.textContaining('Choose'), findsNothing);
      await t.tap(find.text('Accept ₦5,000'));
      await t.tap(find.text('Reject'));
      await t.tap(find.text('Make a different offer'));
      expect(log, ['accept', 'reject', 'counter']);
    });

    testWidgets('while the driver is deciding there is nothing to tap', (t) async {
      await t.pumpWidget(wrap(DropBidResponseCard(response: response(status: 'rider_revised', selectable: false, waitingOn: 'driver'), symbol: '₦', busy: false, onSelect: () {}, onAccept: () {}, onReject: () {}, onCounter: () {})));
      expect(find.textContaining('Waiting for the driver'), findsOneWidget);
      expect(find.textContaining('Choose'), findsNothing);
      expect(find.textContaining('Accept'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('driver incoming bid card', () {
    Map<String, dynamic> bid({Map<String, dynamic>? thread}) => {
          'id': 9,
          'currency': {'symbol': '₦'},
          'offer_fare': 4500,
          'estimate_fare': 5500,
          'earning': 4050,
          'pickup': {'address': 'Wuse Market'},
          'dropoff': {'address': 'Gwarinpa Estate'},
          'stops': [
            {'address': 'Jabi Lake Mall'}
          ],
          'distance': 8.2,
          'distance_unit': 'km',
          'duration_minutes': 19,
          'pickup_distance_km': 1.2,
          'pickup_eta_minutes': 3,
          'payment_method': 'cash',
          'rider': {'first_name': 'Amina', 'completed_trips': 12},
          'seconds_left': 120,
          'expires_at': DateTime.now().add(const Duration(seconds: 120)).toUtc().toIso8601String(),
          'can_counter': true,
          'thread': thread,
        };

    testWidgets('shows the offer, what the driver keeps, the whole route and three actions', (t) async {
      final log = <String>[];
      await t.pumpWidget(MaterialApp(home: Scaffold(body: DropIncomingBidCard(bid: bid(), busy: false, onAccept: () => log.add('accept'), onCounter: () => log.add('counter'), onDecline: () => log.add('decline')))));
      expect(find.byKey(const Key('bid_amount')), findsOneWidget);
      expect(find.text('₦4,500'), findsOneWidget);
      expect(find.textContaining('₦4,050', findRichText: true), findsOneWidget);
      expect(find.textContaining('Jabi Lake'), findsWidgets);
      expect(find.textContaining('Amina · 12 trips'), findsOneWidget);
      expect(find.textContaining('1.2 km · 3 min to pickup'), findsOneWidget);
      await t.tap(find.text('Accept ₦4,500'));
      await t.tap(find.text('Counter'));
      await t.tap(find.text('Decline'));
      expect(log, ['accept', 'counter', 'decline']);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('after answering, the driver waits and may withdraw', (t) async {
      final log = <String>[];
      await t.pumpWidget(MaterialApp(home: Scaffold(body: DropIncomingBidCard(
        bid: bid(thread: {'id': 1, 'status': 'counteroffered', 'amount': 5000, 'my_turn': false, 'can_counter': false, 'seconds_left': 60, 'expires_at': DateTime.now().add(const Duration(seconds: 60)).toUtc().toIso8601String()}),
        busy: false,
        onAccept: () => log.add('accept'),
        onCounter: () {},
        onDecline: () => log.add('withdraw'),
      ))));
      expect(find.textContaining('Waiting for the passenger'), findsOneWidget);
      expect(find.text('₦5,000'), findsOneWidget);
      expect(find.textContaining('Accept'), findsNothing);
      await t.tap(find.text('Withdraw'));
      expect(log, ['withdraw']);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('when the passenger revises, the driver can answer again', (t) async {
      await t.pumpWidget(MaterialApp(home: Scaffold(body: DropIncomingBidCard(
        bid: bid(thread: {'id': 1, 'status': 'rider_revised', 'amount': 4800, 'my_turn': true, 'can_counter': true, 'seconds_left': 60, 'expires_at': DateTime.now().add(const Duration(seconds: 60)).toUtc().toIso8601String()}),
        busy: false,
        onAccept: () {},
        onCounter: () {},
        onDecline: () {},
      ))));
      expect(find.textContaining('changed their offer'), findsOneWidget);
      expect(find.text('Accept ₦4,800'), findsOneWidget);
      expect(find.text('Counter'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('passenger bid screen', () {
    testWidgets('waits for drivers, then lists them as they answer', (t) async {
      final be = FakeBackend(bidMap(declined: 2));
      await launch(t, be, poll: const Duration(milliseconds: 200));
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('bid_offer')), findsOneWidget);
      expect(find.text('₦4,500'), findsOneWidget);
      expect(find.textContaining('Jabi Lake'), findsWidgets);
      expect(find.byKey(const Key('bid_waiting')), findsOneWidget);
      expect(find.textContaining('2 drivers passed'), findsOneWidget);
      be.bid = bidMap(responses: [response(id: 11), response(id: 12, amount: 5000, status: 'counteroffered', selectable: false, canAccept: true)]);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('bid_waiting')), findsNothing);
      expect(find.byKey(const Key('bid_response_11')), findsOneWidget);
      expect(find.byKey(const Key('bid_response_12')), findsOneWidget);
      expect(find.text('Drivers who answered (2)'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('choosing a driver asks the server and finishes as confirmed', (t) async {
      final be = FakeBackend(bidMap(responses: [response(id: 11)]));
      final outcome = await launch(t, be);
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.textContaining('Choose Musa'));
      await t.pumpAndSettle();
      expect(be.calls, contains('select 11'));
      expect(await outcome(), DropBidOutcome.confirmed);
    });

    testWidgets('a refused choice is explained and the bid stays open', (t) async {
      final be = FakeBackend(bidMap(responses: [response(id: 11)]))..selectFailure = ApiFailure('That driver is no longer available. Please choose another driver.');
      await launch(t, be);
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.textContaining('Choose Musa'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('bid_note')), findsOneWidget);
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(find.byKey(const Key('bid_offer')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('an expired bid offers to try again or book a standard ride', (t) async {
      final be = FakeBackend(bidMap(status: 'expired'));
      final outcome = await launch(t, be);
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('bid_ended')), findsOneWidget);
      expect(find.text('No driver answered in time'), findsOneWidget);
      await t.tap(find.text('Book a standard ride'));
      await t.pumpAndSettle();
      expect(await outcome(), DropBidOutcome.standard);
    });

    testWidgets('losing the connection shows a calm banner, and the bid is kept', (t) async {
      final be = FakeBackend(bidMap());
      await launch(t, be, poll: const Duration(milliseconds: 200));
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      be.fail = true;
      await t.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Connection lost'), findsOneWidget);
      be.fail = false;
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Connection lost'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('cancelling asks first, then tells the server', (t) async {
      final be = FakeBackend(bidMap());
      final outcome = await launch(t, be);
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('Cancel bid'));
      await t.pumpAndSettle();
      expect(find.text('Cancel this bid?'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Cancel bid').last);
      await t.pumpAndSettle();
      expect(be.calls, contains('cancel'));
      expect(await outcome(), DropBidOutcome.closed);
    });
  });
}
