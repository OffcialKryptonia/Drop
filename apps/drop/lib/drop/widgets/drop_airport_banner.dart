import 'package:flutter/material.dart';

import '../design/drop_design.dart';

/// Marks a ride as an airport transfer and lists what the driver and passenger need to meet: airport, direction, terminal,
/// flight details typed in by the passenger, and the airport's pickup instructions. It never claims live flight tracking.
class DropAirportBanner extends StatelessWidget {
  const DropAirportBanner({super.key, required this.airport});

  final Map<String, dynamic> airport;

  /// The detail rows, in reading order. Pure, so it can be tested without a widget tree.
  static List<MapEntry<String, String>> rows(Map<String, dynamic> airport) {
    final f = airport['flight'] is Map ? Map<String, dynamic>.from(airport['flight'] as Map) : <String, dynamic>{};
    String s(String k) => (f[k] ?? '').toString().trim();
    final out = <MapEntry<String, String>>[];
    void add(String label, String value) {
      if (value.isNotEmpty) out.add(MapEntry(label, value));
    }

    add('Terminal', s('terminal'));
    final flight = [s('airline'), s('flight_number')].where((e) => e.isNotEmpty).join(' ');
    add('Flight', flight);
    final when = [s('arrival_date'), s('arrival_time')].where((e) => e.isNotEmpty).join(' at ');
    add('Arrival', when);
    add('Passengers', s('passenger_count'));
    add('Luggage', s('luggage_count'));
    add('Passenger note', s('instructions'));
    add('Airport pickup point', (airport['pickup_instructions'] ?? '').toString().trim());
    if (f['has_contact'] == true || s('contact_phone').isNotEmpty) add('Contact', 'Passenger can be reached through in-app call');
    return out;
  }

  static String title(Map<String, dynamic> airport) {
    final label = (airport['label'] ?? (airport['direction'] == 'drop' ? 'Airport Drop' : 'Airport Pickup')).toString();
    final name = (airport['name'] ?? '').toString();
    final code = (airport['iata_code'] ?? '').toString();
    final where = code.isEmpty ? name : '$name ($code)';
    return where.isEmpty ? label : '$label · $where';
  }

  @override
  Widget build(BuildContext context) {
    final items = rows(airport);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DropColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DropRadius.field),
        border: Border.all(color: DropColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flight, size: 18, color: DropColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title(airport), style: TextStyle(fontWeight: FontWeight.w800, color: DropColors.text(context)))),
        ]),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: DropColors.text(context)), children: [
              TextSpan(text: '${e.key}: ', style: TextStyle(color: DropColors.mutedText(context))),
              TextSpan(text: e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
          ),
      ]),
    );
  }
}
