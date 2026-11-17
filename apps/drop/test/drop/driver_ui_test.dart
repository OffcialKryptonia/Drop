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
