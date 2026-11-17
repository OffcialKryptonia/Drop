import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/drop_design.dart';

/// "3:42 PM" in the phone's local time, from an ISO timestamp or a DateTime.
String dropClock(dynamic value) {
  final dt = value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
  if (dt == null) return '';
  return DateFormat('h:mm a').format(dt.toLocal());
}

/// Live ETA for an open ride, from the `eta` object the server sends with the ride:
/// {target: pickup|dropoff, minutes, distance, distance_unit, arrive_at, stale}.
/// [forDriver] changes only the wording ("To pickup" instead of "Your driver arrives").
class DropEtaStrip extends StatelessWidget {
  const DropEtaStrip({super.key, required this.eta, this.forDriver = false, this.dark});

  final Map<String, dynamic> eta;
  final bool forDriver;
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final pickup = eta['target'] == 'pickup';
    final minutes = (eta['minutes'] as num?)?.toInt() ?? 0;
    final stale = eta['stale'] == true;
    final unit = (eta['distance_unit'] ?? 'km').toString();
    final dist = (eta['distance'] as num?)?.toDouble() ?? 0;
    final clock = dropClock(eta['arrive_at']);

    final String label = forDriver
        ? (pickup ? 'To pickup' : 'To drop-off')
        : (pickup ? 'Your driver arrives' : 'You arrive');
    final String big = minutes <= 0 ? (forDriver ? 'Here' : 'Now') : '$minutes min';
    final facts = [
      if (dist > 0) '${dist.toStringAsFixed(1)} $unit',
      if (clock.isNotEmpty && minutes > 0) (forDriver ? 'by $clock' : 'at $clock'),
    ].join(' · ');

    return Semantics(
      label: '$label ${minutes <= 0 ? 'now' : 'in $minutes minutes'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: DropColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(Icons.schedule, color: DropColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DropColors.mutedText(context))),
              if (facts.isNotEmpty) Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DropColors.text(context))),
              if (stale) const Text('Waiting for a fresh location…', style: TextStyle(fontSize: 12, color: Color(0xFFB26A00))),
            ]),
          ),
          const SizedBox(width: 8),
          Text(big, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: DropColors.primary)),
        ]),
      ),
    );
  }
}
