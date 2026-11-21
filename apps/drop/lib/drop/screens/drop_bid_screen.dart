import 'dart:async';

import 'package:flutter/material.dart';

import '../../service/DriverApplicationApi.dart' show ApiFailure;
import '../../service/RideApi.dart';
import '../design/drop_design.dart';
import '../widgets/drop_bid_ui.dart';
import '../widgets/drop_money.dart';
import '../widgets/drop_ride_ui.dart';

/// What the passenger did on the bid screen, so the booking screen knows where to go next.
enum DropBidOutcome { confirmed, standard, retry, closed }

/// The passenger's side of the bid calls. Every answer is the whole bid as the server sees it.
abstract class PassengerBidBackend {
  Future<Map<String, dynamic>> get(int id);
  Future<Map<String, dynamic>> cancel(int id);
  Future<Map<String, dynamic>> revise(int id, num offer);
  Future<Map<String, dynamic>> acceptCounter(int bidId, int responseId);
  Future<Map<String, dynamic>> rejectResponse(int bidId, int responseId);
  Future<Map<String, dynamic>> reviseResponse(int bidId, int responseId, num amount);
  Future<Map<String, dynamic>> select(int bidId, int responseId);
}

class RideApiBidBackend implements PassengerBidBackend {
  const RideApiBidBackend();
  @override
  Future<Map<String, dynamic>> get(int id) => RideApi.getBid(id);
  @override
  Future<Map<String, dynamic>> cancel(int id) => RideApi.cancelBid(id);
  @override
  Future<Map<String, dynamic>> revise(int id, num offer) => RideApi.reviseBid(id, offer);
  @override
  Future<Map<String, dynamic>> acceptCounter(int bidId, int responseId) => RideApi.acceptCounter(bidId, responseId);
  @override
  Future<Map<String, dynamic>> rejectResponse(int bidId, int responseId) => RideApi.rejectResponse(bidId, responseId);
  @override
  Future<Map<String, dynamic>> reviseResponse(int bidId, int responseId, num amount) => RideApi.reviseResponse(bidId, responseId, amount);
  @override
  Future<Map<String, dynamic>> select(int bidId, int responseId) => RideApi.selectDriver(bidId, responseId);
}

/// Shows one bid until it ends: the offer, the countdown, the drivers who answered, and what the passenger may do.
/// The server owns the truth; this screen just keeps asking for it, so a reconnect or a restart loses nothing.
class DropBidScreen extends StatefulWidget {
  const DropBidScreen({super.key, required this.bidId, this.initial, this.backend = const RideApiBidBackend(), this.pollEvery = const Duration(seconds: 3)});

  final int bidId;
  final Map<String, dynamic>? initial;
  final PassengerBidBackend backend;
  final Duration pollEvery;

  @override
  State<DropBidScreen> createState() => _DropBidScreenState();
}

class _DropBidScreenState extends State<DropBidScreen> {
  Map<String, dynamic>? bid;
  Timer? _timer;
  bool _polling = false;
  bool busy = false;
  int _misses = 0;
  int _totalSeconds = 1;
  String? note;

  @override
  void initState() {
    super.initState();
    bid = widget.initial;
    _seen();
    _timer = Timer.periodic(widget.pollEvery, (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.map(_m).toList() : <Map<String, dynamic>>[];

  void _seen() {
    final s = (bid?['seconds_left'] as num?)?.toInt() ?? 0;
    if (s > _totalSeconds) _totalSeconds = s;
  }

  void _apply(Map<String, dynamic> res) {
    final d = _m(res['data']);
    if (d.isEmpty) return;
    bid = d;
    _seen();
    if (d['status'] == 'confirmed') {
      _timer?.cancel();
      Navigator.of(context).pop(DropBidOutcome.confirmed);
    } else if (d['status'] == 'cancelled') {
      _timer?.cancel();
      Navigator.of(context).pop(DropBidOutcome.closed);
    }
  }

  Future<void> _refresh() async {
    if (_polling || !mounted || busy) return;
    _polling = true;
    try {
      final res = await widget.backend.get(widget.bidId);
      if (!mounted) return;
      _misses = 0;
      setState(() => _apply(res));
    } on ApiFailure {
      if (RideApi.lastCode == 'bid_not_found') {
        if (mounted) Navigator.of(context).pop(DropBidOutcome.closed);
      } else if (mounted) {
        setState(() => _misses++);
      }
    } catch (_) {
      if (mounted) setState(() => _misses++);
    }
    _polling = false;
  }

  /// Runs one action. Whatever the server answers is shown; a refusal is explained in plain words, then the screen re-reads the bid.
  Future<void> _do(Future<Map<String, dynamic>> Function() call) async {
    if (busy) return;
    setState(() { busy = true; note = null; });
    try {
      final res = await call();
      if (mounted) setState(() => _apply(res));
    } on ApiFailure catch (e) {
      if (mounted) setState(() => note = e.message);
      busy = false;
      await _refresh();
    }
    if (mounted) setState(() => busy = false);
  }

  Map<String, dynamic> get _limits => _m(bid?['limits']);
  String get _symbol => dropBidSymbol(bid?['currency']);

  Future<void> _counter(Map<String, dynamic> r) async {
    final min = DropMoney.toNum(_limits['min']), max = DropMoney.toNum(_limits['max']);
    final v = await dropAskFare(
      context,
      title: 'Make a different offer',
      hint: 'Tell ${(_m(r['driver'])['name'] ?? 'the driver').toString().split(' ').first} what you would pay.',
      confirmLabel: 'Send offer',
      initial: DropMoney.toNum(bid?['offer_fare']),
      min: min,
      max: max,
      symbol: _symbol,
      reference: DropMoney.toNum(bid?['estimate_fare']),
    );
    if (v != null) await _do(() => widget.backend.reviseResponse(widget.bidId, (r['id'] as num).toInt(), v));
  }

  Future<void> _reviseBid() async {
    final min = DropMoney.toNum(_limits['min']), max = DropMoney.toNum(_limits['max']);
    final left = ((bid?['max_rounds'] as num?)?.toInt() ?? 0) - ((bid?['rounds_used'] as num?)?.toInt() ?? 0);
    final v = await dropAskFare(
      context,
      title: 'Change your offer',
      hint: 'You can change it $left more time${left == 1 ? '' : 's'}. Drivers who already answered keep their own fare.',
      confirmLabel: 'Update offer',
      initial: DropMoney.toNum(bid?['offer_fare']),
      min: min,
      max: max,
      symbol: _symbol,
      reference: DropMoney.toNum(bid?['estimate_fare']),
    );
    if (v != null) await _do(() => widget.backend.revise(widget.bidId, v));
  }

  Future<void> _cancel() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this bid?'),
        content: const Text('Drivers will be told you no longer need a ride at this fare.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep waiting')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel bid'))],
      ),
    );
    if (yes == true) await _do(() => widget.backend.cancel(widget.bidId));
  }

  @override
  Widget build(BuildContext context) {
    final b = bid;
    final status = b?['status']?.toString() ?? 'open';
    final ended = status == 'expired';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ended ? Navigator.of(context).pop(DropBidOutcome.closed) : _cancel();
      },
      child: Scaffold(
        backgroundColor: DropColors.background(context),
        appBar: AppBar(
          title: const Text('Your bid'),
          leading: IconButton(icon: const Icon(Icons.close), tooltip: ended ? 'Close' : 'Cancel bid', onPressed: () => ended ? Navigator.of(context).pop(DropBidOutcome.closed) : _cancel()),
        ),
        body: b == null ? const Center(child: CircularProgressIndicator()) : _body(b, ended),
      ),
    );
  }

  Widget _body(Map<String, dynamic> b, bool ended) {
    final responses = _l(b['responses']);
    final pickup = _m(b['pickup']);
    final drop = _m(b['dropoff']);
    final declined = (b['declined_count'] as num?)?.toInt() ?? 0;
    final expires = DateTime.tryParse(b['expires_at']?.toString() ?? '');
    return Column(children: [
      if (_misses >= 2)
        Container(
          width: double.infinity,
          color: Colors.orange.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(children: [Icon(Icons.wifi_off, size: 18), SizedBox(width: 8), Expanded(child: Text('Connection lost. Retrying… your bid is still safe.'))]),
        ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: DropColors.hairline(context))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your offer', style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(DropMoney.format(b['offer_fare'], symbol: _symbol), key: const Key('bid_offer'), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: DropColors.text(context)))),
                    Text('DROP estimate ${DropMoney.format(b['estimate_fare'], symbol: _symbol)}', style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
                  ]),
                ),
                if (!ended) DropCountdownRing(expiresAt: expires, totalSeconds: _totalSeconds),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                DropFactChip(icon: Icons.route, text: '${DropMoney.toNum(b['distance']).toStringAsFixed(1)} ${b['distance_unit'] ?? 'km'} · about ${DropMoney.toNum(b['duration_minutes']).round()} min'),
                DropFactChip(icon: (b['payment_method'] == 'wallet') ? Icons.account_balance_wallet_outlined : Icons.payments_outlined, text: b['payment_method'] == 'wallet' ? 'Wallet' : 'Cash'),
              ]),
              const SizedBox(height: 12),
              DropStopTimeline(pickup: (pickup['address'] ?? '').toString(), dropoff: (drop['address'] ?? '').toString(), stops: _l(b['stops'])),
              if (!ended && b['can_revise'] == true) Padding(padding: const EdgeInsets.only(top: 8), child: TextButton.icon(onPressed: busy ? null : _reviseBid, icon: const Icon(Icons.edit, size: 18), label: const Text('Change my offer'))),
            ]),
          ),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(note!, key: const Key('bid_note'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          if (ended) _endedCard(responses.isNotEmpty) else ...[
            Text(responses.isEmpty ? 'Waiting for drivers' : 'Drivers who answered (${responses.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DropColors.text(context))),
            const SizedBox(height: 10),
            if (responses.isEmpty)
              Container(
                key: const Key('bid_waiting'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 14),
                  Text('Nearby drivers can see your offer.', textAlign: TextAlign.center, style: TextStyle(color: DropColors.text(context), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(declined > 0 ? '$declined driver${declined == 1 ? '' : 's'} passed. Try a slightly higher offer to get more answers.' : 'We will show their answers here as they come in.', textAlign: TextAlign.center, style: TextStyle(color: DropColors.mutedText(context))),
                ]),
              ),
            for (final r in responses)
              DropBidResponseCard(
                response: r,
                symbol: _symbol,
                busy: busy,
                onSelect: () => _do(() => widget.backend.select(widget.bidId, (r['id'] as num).toInt())),
                onAccept: () => _do(() => widget.backend.acceptCounter(widget.bidId, (r['id'] as num).toInt())),
                onReject: () => _do(() => widget.backend.rejectResponse(widget.bidId, (r['id'] as num).toInt())),
                onCounter: () => _counter(r),
              ),
            const SizedBox(height: 8),
            Center(child: Text('You choose your driver. Nobody is assigned until you do.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DropColors.mutedText(context)))),
            const SizedBox(height: 8),
            Center(child: TextButton(onPressed: busy ? null : _cancel, child: const Text('Cancel bid', style: TextStyle(color: Colors.red)))),
          ],
        ]),
      ),
    ]);
  }

  Widget _endedCard(bool hadResponses) => Container(
        key: const Key('bid_ended'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          const Icon(Icons.timer_off_outlined, size: 40),
          const SizedBox(height: 10),
          Text(hadResponses ? 'This bid ran out of time' : 'No driver answered in time', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DropColors.text(context))),
          const SizedBox(height: 4),
          Text('You can try again with a new offer, or book a standard ride at the DROP price.', textAlign: TextAlign.center, style: TextStyle(color: DropColors.mutedText(context))),
          const SizedBox(height: 16),
          DropActionButton(label: 'Try a new offer', primary: true, onPressed: () => Navigator.of(context).pop(DropBidOutcome.retry)),
          const SizedBox(height: 10),
          DropActionButton(label: 'Book a standard ride', onPressed: () => Navigator.of(context).pop(DropBidOutcome.standard)),
        ]),
      );
}
