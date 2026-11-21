import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/drop_design.dart';
import 'drop_money.dart';
import 'drop_ride_ui.dart';

/// Presentation for optional fare bidding. No API calls and no rules: every limit, amount and status shown here
/// was decided by the server, and the server re-checks everything the person taps.

String dropBidSymbol(dynamic currency) => currency is Map ? (currency['symbol']?.toString() ?? DropMoney.naira) : DropMoney.naira;

/// A sensible +/- step for a fare: ₦50 for small fares, up to ₦500 for large ones.
double dropFareStep(double reference) {
  if (reference < 3000) return 50;
  if (reference < 10000) return 100;
  if (reference < 30000) return 250;
  return 500;
}

/// The fare editor: big amount, − / + buttons, tap the amount to type it, and the allowed range always in view.
/// The range is only a hint here; the server decides.
class DropFareEditor extends StatelessWidget {
  const DropFareEditor({
    super.key,
    required this.amount,
    required this.min,
    required this.max,
    required this.onChanged,
    this.symbol = DropMoney.naira,
    this.step,
    this.reference,
    this.referenceLabel = 'DROP estimate',
    this.quick = const [],
  });

  final double amount;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String symbol;
  final double? step;
  final double? reference;
  final String referenceLabel;
  final List<double> quick;

  double get _step => step ?? dropFareStep(reference ?? amount);
  double _clamp(double v) => v.clamp(min, max).toDouble();

  Future<void> _type(BuildContext context) async {
    final c = TextEditingController(text: amount.round().toString());
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter your fare'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(prefixText: symbol, helperText: 'Between ${DropMoney.format(min, symbol: symbol)} and ${DropMoney.format(max, symbol: symbol)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text)), child: const Text('Done')),
        ],
      ),
    );
    if (v != null && v > 0) onChanged(_clamp(v));
  }

  @override
  Widget build(BuildContext context) {
    final canDown = amount - _step >= min - 0.001;
    final canUp = amount + _step <= max + 0.001;
    Widget round(IconData icon, bool on, VoidCallback tap, String label) => Semantics(
          button: true,
          label: label,
          child: Material(
            color: on ? DropColors.primary.withValues(alpha: 0.12) : DropColors.hairline(context),
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: on ? tap : null, child: SizedBox(width: 52, height: 52, child: Icon(icon, color: on ? DropColors.primary : DropColors.mutedText(context)))),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        round(Icons.remove, canDown, () => onChanged(_clamp(amount - _step)), 'Lower the fare'),
        Expanded(
          child: InkWell(
            onTap: () => _type(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(DropMoney.format(amount, symbol: symbol), key: const Key('fare_amount'), style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: DropColors.text(context)))),
                Text('Tap to type', style: TextStyle(fontSize: 12, color: DropColors.mutedText(context))),
              ]),
            ),
          ),
        ),
        round(Icons.add, canUp, () => onChanged(_clamp(amount + _step)), 'Raise the fare'),
      ]),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: DropColors.hairline(context))),
        child: Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: DropColors.mutedText(context)), children: [
          if (reference != null) ...[TextSpan(text: '$referenceLabel '), TextSpan(text: DropMoney.format(reference, symbol: symbol), style: TextStyle(fontWeight: FontWeight.w800, color: DropColors.text(context))), const TextSpan(text: ' · ')],
          TextSpan(text: 'You can offer ${DropMoney.format(min, symbol: symbol)} to ${DropMoney.format(max, symbol: symbol)}'),
        ])),
      ),
      if (quick.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in quick)
            ChoiceChip(label: Text(DropMoney.format(q, symbol: symbol)), selected: (amount - q).abs() < 0.5, onSelected: (_) => onChanged(_clamp(q))),
        ]),
      ],
    ]);
  }
}

/// Opens the fare editor in a sheet and returns the confirmed amount (null when dismissed).
Future<double?> dropAskFare(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required double initial,
  required double min,
  required double max,
  String symbol = DropMoney.naira,
  double? reference,
  String referenceLabel = 'DROP estimate',
  String? hint,
  List<double> quick = const [],
}) {
  var amount = initial.clamp(min, max).toDouble();
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DropSheet(
          maxHeightFactor: 0.8,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DropColors.text(ctx))),
            if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: TextStyle(fontSize: 14, color: DropColors.mutedText(ctx)))),
            const SizedBox(height: 16),
            DropFareEditor(amount: amount, min: min, max: max, symbol: symbol, reference: reference, referenceLabel: referenceLabel, quick: quick, onChanged: (v) => setS(() => amount = v)),
            const SizedBox(height: 16),
            DropActionButton(label: '$confirmLabel · ${DropMoney.format(amount, symbol: symbol)}', primary: true, onPressed: () => Navigator.pop(ctx, amount)),
          ]),
        ),
      ),
    ),
  );
}

/// Plain-words text for a driver's thread, from the passenger's point of view.
String dropResponseNote(Map<String, dynamic> r) {
  switch (r['status']) {
    case 'driver_accepted_offer':
      return 'Accepted your offer';
    case 'counteroffered':
      return 'Counteroffer';
    case 'rider_revised':
      return 'Waiting for the driver to answer your offer';
    case 'passenger_accepted_counteroffer':
      return 'Fare agreed';
    default:
      return '';
  }
}

/// One driver's response on the passenger's bid screen: who they are, what they ask, and what the passenger can do.
class DropBidResponseCard extends StatelessWidget {
  const DropBidResponseCard({
    super.key,
    required this.response,
    required this.symbol,
    required this.busy,
    required this.onSelect,
    required this.onAccept,
    required this.onReject,
    required this.onCounter,
  });

  final Map<String, dynamic> response;
  final String symbol;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCounter;

  @override
  Widget build(BuildContext context) {
    final r = response;
    final d = (r['driver'] is Map) ? Map<String, dynamic>.from(r['driver'] as Map) : <String, dynamic>{};
    final v = (d['vehicle'] is Map) ? Map<String, dynamic>.from(d['vehicle'] as Map) : <String, dynamic>{};
    final amount = DropMoney.format(r['amount'], symbol: symbol);
    final rating = d['rating'];
    final image = d['profile_image']?.toString();
    final km = d['distance_km'];
    final eta = d['eta_minutes'];
    final vehicle = [v['colour'], v['make'], v['model']].where((x) => x != null && x.toString().isNotEmpty).join(' ');
    final plate = v['plate']?.toString() ?? '';
    final selectable = r['selectable'] == true;
    final canAccept = r['can_accept'] == true;
    final waiting = r['waiting_on'] == 'driver';
    final note = dropResponseNote(r);
    final noteColor = selectable ? DropColors.success : (canAccept ? DropColors.amber : DropColors.mutedText(context));
    return Container(
      key: Key('bid_response_${r['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DropColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selectable ? DropColors.success.withValues(alpha: 0.6) : DropColors.hairline(context), width: selectable ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          CircleAvatar(radius: 26, backgroundColor: DropColors.hairline(context), backgroundImage: (image != null && image.isNotEmpty) ? NetworkImage(image) : null, child: (image == null || image.isEmpty) ? Icon(Icons.person, color: DropColors.mutedText(context)) : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((d['name'] ?? 'Driver').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: DropColors.text(context))),
              Row(children: [
                const Icon(Icons.star_rounded, size: 18, color: DropColors.amber),
                const SizedBox(width: 2),
                Text(rating == null ? 'New' : '${DropMoney.toNum(rating).toStringAsFixed(1)} (${d['rating_count'] ?? 0})', style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
                Text('  ·  ${d['completed_rides'] ?? 0} trips', style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Text(amount, key: Key('bid_response_amount_${r['id']}'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DropColors.text(context))),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (vehicle.isNotEmpty) DropFactChip(icon: Icons.directions_car_outlined, text: plate.isEmpty ? vehicle : '$vehicle · $plate'),
          if (km != null) DropFactChip(icon: Icons.my_location, text: '${DropMoney.toNum(km).toStringAsFixed(1)} km${eta != null ? ' · $eta min away' : ''}'),
        ]),
        if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(note, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: noteColor))),
        const SizedBox(height: 12),
        if (selectable)
          DropActionButton(label: 'Choose ${(d['name'] ?? 'this driver').toString().split(' ').first} · $amount', primary: true, loading: busy, onPressed: busy ? null : onSelect)
        else if (canAccept)
          Row(children: [
            Expanded(child: DropActionButton(label: 'Reject', onPressed: busy ? null : onReject)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: DropActionButton(label: 'Accept $amount', primary: true, loading: busy, onPressed: busy ? null : onAccept)),
          ])
        else if (waiting)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        if (canAccept && r['can_revise'] == true) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: TextButton(onPressed: busy ? null : onCounter, child: const Text('Make a different offer')))),
        if (selectable) Padding(padding: const EdgeInsets.only(top: 4), child: Center(child: TextButton(onPressed: busy ? null : onReject, child: const Text('Not this driver')))),
      ]),
    );
  }
}

/// A bid as a driver sees it: the fare on the table, what they would keep, the whole route, and Accept / Counter / Decline.
class DropIncomingBidCard extends StatelessWidget {
  const DropIncomingBidCard({
    super.key,
    required this.bid,
    required this.busy,
    required this.onAccept,
    required this.onCounter,
    required this.onDecline,
    this.index = 0,
    this.total = 1,
  });

  final Map<String, dynamic> bid;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onCounter;
  final VoidCallback onDecline;
  final int index;
  final int total;

  Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final b = bid;
    final symbol = dropBidSymbol(b['currency']);
    final thread = b['thread'] == null ? null : _m(b['thread']);
    final myTurn = thread == null || thread['my_turn'] == true;
    final amount = thread != null ? thread['amount'] : b['offer_fare'];
    final pickup = _m(b['pickup']);
    final drop = _m(b['dropoff']);
    final stops = (b['stops'] is List) ? (b['stops'] as List).map(_m).toList() : <Map<String, dynamic>>[];
    final rider = _m(b['rider']);
    final eta = b['pickup_eta_minutes'];
    final unit = (b['distance_unit'] ?? 'km').toString();
    final cash = b['payment_method'] != 'wallet';
    final expires = DateTime.tryParse((thread?['expires_at'] ?? b['expires_at'])?.toString() ?? '');
    final secs = ((thread?['seconds_left'] ?? b['seconds_left']) as num?)?.toInt() ?? 60;
    final agreed = thread != null && (thread['status'] == 'driver_accepted_offer' || thread['status'] == 'passenger_accepted_counteroffer');
    final canCounter = thread == null ? b['can_counter'] == true : thread['can_counter'] == true;
    final title = thread == null ? 'Passenger offers' : (agreed ? 'Fare agreed. Waiting for the passenger to choose' : (myTurn ? 'Passenger changed their offer' : 'Your counteroffer'));
    return DropSheet(
      key: Key('incoming_bid_${b['id']}'),
      maxHeightFactor: 0.78,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(total > 1 ? 'Passenger bid · ${index + 1} of $total' : 'Passenger bid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DropColors.mutedText(context))),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DropColors.mutedText(context))),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(DropMoney.format(amount, symbol: symbol), key: const Key('bid_amount'), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: DropColors.text(context)))),
              Text.rich(TextSpan(style: TextStyle(fontSize: 14, color: DropColors.mutedText(context)), children: [
                const TextSpan(text: 'DROP estimate '),
                TextSpan(text: DropMoney.format(b['estimate_fare'], symbol: symbol)),
                const TextSpan(text: ' · You earn '),
                TextSpan(text: DropMoney.format(b['earning'], symbol: symbol), style: const TextStyle(fontWeight: FontWeight.w800, color: DropColors.success)),
              ])),
            ]),
          ),
          const SizedBox(width: 12),
          DropCountdownRing(expiresAt: expires, totalSeconds: secs < 1 ? 1 : secs),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DropFactChip(icon: cash ? Icons.payments_outlined : Icons.account_balance_wallet_outlined, text: cash ? 'Cash' : 'Wallet'),
          DropFactChip(icon: Icons.my_location, text: '${DropMoney.toNum(b['pickup_distance_km']).toStringAsFixed(1)} km${eta != null ? ' · $eta min' : ''} to pickup'),
          DropFactChip(icon: Icons.route, text: 'Trip ${DropMoney.toNum(b['distance']).toStringAsFixed(1)} $unit · ${DropMoney.toNum(b['duration_minutes']).round()} min'),
          if (rider['first_name'] != null) DropFactChip(icon: Icons.person_outline, text: '${rider['first_name']} · ${rider['completed_trips'] ?? 0} trips'),
        ]),
        const SizedBox(height: 14),
        DropStopTimeline(pickup: (pickup['address'] ?? '').toString(), dropoff: (drop['address'] ?? '').toString(), stops: stops),
        const SizedBox(height: 14),
        if (thread != null && !myTurn)
          Row(children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(agreed ? 'The passenger is choosing a driver.' : 'Waiting for the passenger to answer.', style: TextStyle(color: DropColors.mutedText(context)))),
            TextButton(onPressed: busy ? null : onDecline, child: const Text('Withdraw')),
          ])
        else
          Row(children: [
            Expanded(child: DropActionButton(label: 'Decline', onPressed: busy ? null : onDecline)),
            if (canCounter) ...[
              const SizedBox(width: 8),
              Expanded(child: DropActionButton(label: 'Counter', icon: Icons.swap_vert, onPressed: busy ? null : onCounter)),
            ],
            const SizedBox(width: 8),
            Expanded(flex: 2, child: DropActionButton(label: 'Accept ${DropMoney.format(amount, symbol: symbol)}', primary: true, loading: busy, onPressed: busy ? null : onAccept)),
          ]),
      ]),
    );
  }
}
