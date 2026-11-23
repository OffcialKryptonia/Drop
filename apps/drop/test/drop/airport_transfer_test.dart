import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/drop/widgets/drop_airport_banner.dart';
import 'package:drop/service/AirportTransfer.dart';

Map<String, dynamic> _api() => {
      'status': true,
      'flight_tracking': false,
      'flight_fields': {
        'pickup': {
          'flight_number': {'enabled': true, 'required': true},
          'terminal': {'enabled': true, 'required': true},
          'airline': {'enabled': true, 'required': false},
          'contact_phone': {'enabled': false, 'required': false},
        },
        'drop': {
          'flight_number': {'enabled': true, 'required': false},
          'instructions': {'enabled': true, 'required': false},
        },
      },
      'data': [
        {'id': 1, 'name': 'Test Airport', 'iata_code': 'TST', 'latitude': 9.0, 'longitude': 7.0, 'terminals': [{'name': 'T1'}, {'name': ' '}, {'name': 'T2'}], 'pickup_instructions': 'Door 4'},
        {'id': 'bad', 'name': 'Broken'},
      ],
    };

void main() {
  group('AirportConfig', () {
    final c = AirportConfig.fromApi(_api());

    test('reads airports from the server and skips malformed rows', () {
      expect(c.airports.length, 1);
      expect(c.airports.first.label, 'Test Airport (TST)');
      expect(c.airports.first.terminals, ['T1', 'T2']);
    });

    test('shows only the fields the admin enabled, in a stable order', () {
      expect(c.shown('pickup'), ['airline', 'flight_number', 'terminal']);
      expect(c.shown('drop'), ['flight_number', 'instructions']);
    });

    test('a required field is always shown', () {
      final x = AirportConfig.fromApi({'flight_fields': {'pickup': {'airline': {'enabled': false, 'required': true}}}, 'data': []});
      expect(x.shown('pickup'), ['airline']);
    });

    test('reports required fields that are still empty', () {
      expect(c.missing('pickup', {}), ['flight_number', 'terminal']);
      expect(c.missing('pickup', {'flight_number': 'KQ530', 'terminal': ' '}), ['terminal']);
      expect(c.missing('pickup', {'flight_number': 'KQ530', 'terminal': 'T1'}), isEmpty);
      expect(c.missing('drop', {}), isEmpty);
    });

    test('sends only shown, filled-in fields', () {
      expect(c.payload('pickup', {'flight_number': ' KQ530 ', 'terminal': 'T1', 'instructions': 'ignored', 'airline': ''}), {'flight_number': 'KQ530', 'terminal': 'T1'});
    });

    test('with nothing configured nothing is shown or required', () {
      final e = AirportConfig.fromApi({});
      expect(e.airports, isEmpty);
      expect(e.shown('drop'), isEmpty);
      expect(e.missing('pickup', {}), isEmpty);
    });
  });

  test('direction titles', () {
    expect(AirportDirection.title(AirportDirection.drop), 'Airport Drop');
    expect(AirportDirection.title(AirportDirection.pickup), 'Airport Pickup');
  });

  group('DropAirportBanner', () {
    final airport = {
      'label': 'Airport Pickup',
      'name': 'Test Airport',
      'iata_code': 'TST',
      'direction': 'pickup',
      'pickup_instructions': 'Door 4',
      'flight': {'airline': 'Air X', 'flight_number': 'KQ530', 'terminal': 'T1', 'arrival_date': '2026-12-01', 'arrival_time': '07:45', 'passenger_count': 2, 'instructions': 'Meet at arrivals', 'has_contact': true},
    };

    test('title shows direction, airport and code', () {
      expect(DropAirportBanner.title(airport), 'Airport Pickup · Test Airport (TST)');
    });

    test('rows list terminal, flight, arrival, passengers, notes and pickup point', () {
      final r = {for (final e in DropAirportBanner.rows(airport)) e.key: e.value};
      expect(r['Terminal'], 'T1');
      expect(r['Flight'], 'Air X KQ530');
      expect(r['Arrival'], '2026-12-01 at 07:45');
      expect(r['Passengers'], '2');
      expect(r['Passenger note'], 'Meet at arrivals');
      expect(r['Airport pickup point'], 'Door 4');
      expect(r['Contact'], contains('in-app call'));
    });

    test('never shows a raw phone number or claims tracking', () {
      final r = DropAirportBanner.rows({'flight': {'flight_number': 'KQ1', 'contact_phone': '08031234567'}});
      expect(r.map((e) => '${e.key}${e.value}').join(), isNot(contains('0803')));
      expect(r.map((e) => e.value.toLowerCase()).join(), isNot(contains('live')));
    });

    testWidgets('renders in a driver sheet', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: DropAirportBanner(airport: airport))));
      expect(find.text('Airport Pickup · Test Airport (TST)'), findsOneWidget);
      expect(find.textContaining('KQ530'), findsOneWidget);
    });
  });
}
