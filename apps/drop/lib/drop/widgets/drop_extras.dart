import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/DriverApplicationApi.dart' show ApiFailure;
import '../../service/RideApi.dart';
import '../design/drop_design.dart';
import 'drop_money.dart';
import 'drop_ride_ui.dart';

const _kinds = <(String, String, IconData)>[
  ('toll', 'Toll', Icons.toll),
  ('parking', 'Parking', Icons.local_parking),
  ('waiting', 'Waiting', Icons.hourglass_bottom),
  ('other', 'Other', Icons.more_horiz),
];

String dropExtraLabel(dynamic kind) => switch ('$kind') {
      'toll' => 'Toll',
      'parking' => 'Parking',
      'waiting' => 'Waiting time',
      _ => 'Extra charge',
    };

/// Driver: add a toll, parking or waiting charge to a finished trip. Returns true when it was sent.
Future<bool> showDropAddExtraSheet(BuildContext context, {required int rideId}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom), child: _AddExtra(rideId: rideId)),
  );
  return sent == true;
}

class _AddExtra extends StatefulWidget {
  const _AddExtra({required this.rideId});
  final int rideId;

  @override
  State<_AddExtra> createState() => _AddExtraState();
}

class _AddExtraState extends State<_AddExtra> {
  String _kind = 'toll';
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  bool _loading = true;
  bool _canAdd = true;
  num _remaining = 0;
  int _window = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final r = await RideApi.driverExtras(widget.rideId);
      _canAdd = r['can_add'] == true;
      _remaining = (r['remaining'] as num?) ?? 0;
      _window = (r['window_minutes'] as num?)?.toInt() ?? 30;
    } catch (_) {
      // let the server decide when the driver presses Send
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RideApi.proposeExtra(widget.rideId, kind: _kind, amount: amount, note: _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return DropSheet(
      maxHeightFactor: 0.9,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add an extra charge', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DropColors.text(context))),
        const SizedBox(height: 4),
        Text('The passenger must approve it, then pays from their wallet or in cash.', style: TextStyle(fontSize: 14, color: DropColors.mutedText(context))),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (!_canAdd)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('You can’t add an extra charge to this trip now. It must be within $_window minutes of the trip ending, within the limit, and with no earlier charge still waiting.', style: TextStyle(fontSize: 15, color: DropColors.text(context))),
          )
        else ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in _kinds)
              ChoiceChip(
                avatar: Icon(k.$3, size: 18),
                label: Text(k.$2),
                selected: _kind == k.$1,
                onSelected: (_) => setState(() => _kind = k.$1),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(prefixText: '${DropMoney.naira} ', labelText: 'Amount', helperText: 'Up to ${DropMoney.format(_remaining)}', border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, maxLength: 120, decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder())),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14))),
          const SizedBox(height: 4),
          DropActionButton(label: 'Send to passenger', primary: true, loading: _busy, onPressed: _busy ? null : _send),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_canAdd ? 'Cancel' : 'Close')),
      ]),
    );
  }
}

/// Passenger: approve and pay, or decline, one extra charge from the driver. Returns true if it was answered.
Future<bool> showDropExtraRequestSheet(BuildContext context, Map<String, dynamic> extra, {required num walletBalance}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (c) => _ExtraRequest(extra: extra, walletBalance: walletBalance),
  );
  return done == true;
}

class _ExtraRequest extends StatefulWidget {
  const _ExtraRequest({required this.extra, required this.walletBalance});
  final Map<String, dynamic> extra;
  final num walletBalance;

  @override
  State<_ExtraRequest> createState() => _ExtraRequestState();
}

class _ExtraRequestState extends State<_ExtraRequest> {
  bool _busy = false;
  String? _error;

  String get _sym => (((widget.extra['currency'] as Map?)?['symbol']) ?? DropMoney.naira).toString();

  Future<void> _run(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.extra;
    final id = (e['id'] as num).toInt();
    final amount = DropMoney.toNum(e['amount']);
    final enough = widget.walletBalance >= amount;
    final name = (e['driver_first_name'] ?? 'Your driver').toString();
    final note = (e['note'] ?? '').toString();
    return DropSheet(
      maxHeightFactor: 0.8,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Extra charge from $name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DropColors.text(context))),
        const SizedBox(height: 10),
        Center(child: DropMoneyText(amount, symbol: _sym, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: DropColors.text(context)))),
        const SizedBox(height: 4),
        Center(child: Text(dropExtraLabel(e['kind']) + (note.isNotEmpty ? ' · $note' : ''), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: DropColors.mutedText(context)))),
        const SizedBox(height: 16),
        DropActionButton(
          label: enough ? 'Pay from wallet' : 'Wallet too low (${DropMoney.format(widget.walletBalance, symbol: _sym)})',
          primary: true,
          icon: Icons.account_balance_wallet_outlined,
          loading: _busy,
          onPressed: (_busy || !enough) ? null : () => _run(() => RideApi.payExtra(id, 'wallet')),
        ),
        const SizedBox(height: 10),
        DropActionButton(label: 'I’ll pay cash', icon: Icons.payments_outlined, onPressed: _busy ? null : () => _run(() => RideApi.payExtra(id, 'cash'))),
        const SizedBox(height: 10),
        DropActionButton(label: 'Decline', danger: true, onPressed: _busy ? null : () => _run(() => RideApi.declineExtra(id))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 14))),
        const SizedBox(height: 6),
        Text('Only approve a charge you agree with. You can decline it.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DropColors.mutedText(context))),
      ]),
    );
  }
}
