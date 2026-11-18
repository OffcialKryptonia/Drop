import 'package:drop/drop/widgets/drop_eta.dart';
import 'package:drop/drop/widgets/drop_extras.dart';
import 'package:drop/drop/widgets/drop_money.dart';
import 'package:drop/drop/widgets/drop_ride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double scale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 740), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
      ),
    );

void main() {
  etaTests();
  receiptTests();
  extraTests();
  group('DropMoney.format', () {
    test('positive, whole and fractional', () {
      expect(DropMoney.format(2912.96), '₦2,912.96');
      expect(DropMoney.format(1500), '₦1,500');
      expect(DropMoney.format('3000'), '₦3,000');
    });
    test('negative puts the sign before the symbol', () {
      expect(DropMoney.format(-436.94), '-₦436.94');
    });
    test('zero and null have no sign', () {
      expect(DropMoney.format(0), '₦0');
      expect(DropMoney.format(null), '₦0');
      expect(DropMoney.format(-0.001), '₦0');
    });
    test('large amounts and signed rows', () {
      expect(DropMoney.format(1234567.5), '₦1,234,567.50');
      expect(DropMoney.format(500, signed: true), '+₦500');
      expect(DropMoney.format(-500, signed: true), '-₦500');
    });
  });

  test('splitAddress separates place name from the rest', () {
    final s = splitAddress('Winnie Plaza, Abacha Road, Katampe');
    expect(s.name, 'Winnie Plaza');
    expect(s.rest, 'Abacha Road, Katampe');
    expect(splitAddress('').name, 'Selected place');
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('request-style sheet fits at 360dp, text scale $scale', (t) async {
      await t.pumpWidget(_host(
        DropSheet(
          maxHeightFactor: 0.7,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropMoneyText(1500, style: const TextStyle(fontSize: 32)),
            DropStopTimeline(pickup: 'Winnie Plaza, Abacha Road, Katampe, Abuja', dropoff: 'Jabi Lake Mall, Bala Sokoto Way, Jabi, Abuja'),
            Row(children: [
              Expanded(flex: 2, child: DropActionButton(label: 'Decline', onPressed: () {})),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: DropActionButton(label: 'Accept', primary: true, onPressed: () {})),
            ]),
          ]),
        ),
        scale: scale,
      ));
      expect(tester_exception(t), isNull);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('₦1,500'), findsOneWidget);
    });
  }

  testWidgets('countdown ring shows seconds left', (t) async {
    await t.pumpWidget(_host(DropCountdownRing(expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 20)), totalSeconds: 30)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

Object? tester_exception(WidgetTester t) => t.takeException();

void etaTests() {
  testWidgets('ETA strip shows minutes, distance and arrival for the rider', (t) async {
    await t.pumpWidget(_host(DropEtaStrip(eta: {'target': 'pickup', 'minutes': 4, 'distance': 1.8, 'distance_unit': 'km', 'arrive_at': '2026-11-17T14:42:00Z', 'stale': false})));
    expect(find.text('4 min'), findsOneWidget);
    expect(find.text('Your driver arrives'), findsOneWidget);
    expect(find.textContaining('1.8 km'), findsOneWidget);
  });
  testWidgets('ETA strip: driver wording, arriving now and stale note', (t) async {
    await t.pumpWidget(_host(DropEtaStrip(forDriver: true, eta: {'target': 'dropoff', 'minutes': 0, 'distance': 0.0, 'distance_unit': 'km', 'arrive_at': '2026-11-17T14:42:00Z', 'stale': true})));
    expect(find.text('To drop-off'), findsOneWidget);
    expect(find.text('Here'), findsOneWidget);
    expect(find.textContaining('Waiting for a fresh location'), findsOneWidget);
  });
  test('dropClock handles bad input', () {
    expect(dropClock(null), '');
    expect(dropClock('nope'), '');
  });
}

void receiptTests() {
  testWidgets('DropMoneyText uses the given currency symbol', (t) async {
    await t.pumpWidget(_host(const DropMoneyText(1500, symbol: 'GH₵')));
    expect(find.text('GH₵1,500'), findsOneWidget);
  });
}

void extraTests() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('extra-charge request sheet fits at 360dp, scale $scale, wallet too low', (t) async {
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(360, 740), textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => showDropExtraRequestSheet(c, {'id': 5, 'amount': 500, 'kind': 'toll', 'note': 'Lekki toll', 'driver_first_name': 'Musa', 'currency': {'symbol': '₦'}}, walletBalance: 100), child: const Text('open')))),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('₦500'), findsOneWidget);
      expect(find.textContaining('Wallet too low'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(dropExtraLabel('parking'), 'Parking');
    });
  }
}
