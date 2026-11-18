import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../service/RideApi.dart';
import '../design/drop_design.dart';
import '../widgets/drop_extras.dart';
import '../widgets/drop_money.dart';
import '../widgets/drop_ride_ui.dart';

/// One finished trip as a numbered receipt. The rider copy shows the fare lines and who drove;
/// the driver copy shows the fare, DROP commission and what the driver earned.
class DropReceiptScreen extends StatefulWidget {
  const DropReceiptScreen({super.key, required this.rideId, required this.driver});

  final int rideId;
  final bool driver;

  @override
  State<DropReceiptScreen> createState() => _DropReceiptScreenState();
}

class _DropReceiptScreenState extends State<DropReceiptScreen> {
  Map<String, dynamic>? _r;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = widget.driver ? await RideApi.driverReceipt(widget.rideId) : await RideApi.receipt(widget.rideId);
      final d = res['data'];
      if (d is Map) {
        _r = Map<String, dynamic>.from(d);
      } else {
        _error = (res['message'] ?? 'No receipt for this trip yet.').toString();
      }
    } catch (e) {
      _error = 'Could not load the receipt. Check your connection and try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _sym(Map<String, dynamic> r) => ((r['currency'] as Map?)?['symbol'] ?? DropMoney.naira).toString();
  String _m(Map<String, dynamic> r, dynamic v, {bool signed = false}) => DropMoney.format(v, symbol: _sym(r), signed: signed);
  String _date(dynamic v) {
    final dt = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    return dt == null ? '' : DateFormat('d MMM yyyy, h:mm a').format(dt);
  }

  String _payLabel(Map<String, dynamic> r) => r['paid_with'] == 'wallet' ? 'Wallet' : 'Cash';

  String _asText(Map<String, dynamic> r) {
    final b = StringBuffer()
      ..writeln('DROP receipt ${r['number']}')
      ..writeln(_date(r['issued_at']))
      ..writeln('From: ${r['pickup'] ?? ''}')
      ..writeln('To: ${r['dropoff'] ?? ''}');
    for (final l in (r['lines'] as List? ?? [])) {
      b.writeln('${l['label']}: ${_m(r, l['amount'])}');
    }
    if (widget.driver) {
      b
        ..writeln('Fare: ${_m(r, r['fare'])}')
        ..writeln('DROP commission: ${_m(r, -DropMoney.toNum(r['commission']))}')
        ..writeln('Your earning: ${_m(r, r['earning'])}');
    } else {
      b.writeln('Total: ${_m(r, r['total'])}');
    }
    b.writeln('Paid with: ${_payLabel(r)}');
    return b.toString();
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: DropColors.hairline(context))),
        child: child,
      );

  Widget _body(Map<String, dynamic> r) {
    final lines = (r['lines'] as List? ?? []).whereType<Map>().toList();
    final fee = DropMoney.toNum(r['cancellation_fee']);
    final driver = r['driver'] as Map?;
    final cash = r['collect_cash'] == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RECEIPT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: DropColors.mutedText(context))),
          const SizedBox(height: 2),
          Text('${r['number']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DropColors.text(context))),
          const SizedBox(height: 2),
          Text(_date(r['issued_at']), style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
          const SizedBox(height: 14),
          DropStopTimeline(pickup: (r['pickup'] ?? '').toString(), dropoff: (r['dropoff'] ?? '').toString()),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (r['service'] != null) DropFactChip(icon: Icons.directions_car_outlined, text: r['service'].toString()),
            DropFactChip(icon: Icons.route, text: '${DropMoney.toNum(r['distance']).toStringAsFixed(1)} ${r['distance_unit'] ?? 'km'} · ${DropMoney.toNum(r['duration_minutes']).round()} min'),
          ]),
        ])),
        if (!widget.driver && driver != null)
          _card(Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: DropColors.primary.withValues(alpha: 0.12),
              child: Text(((driver['name'] ?? '?').toString().isEmpty ? '?' : (driver['name'] ?? '?').toString()[0]).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: DropColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((driver['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DropColors.text(context))),
                Text([driver['vehicle'], driver['plate']].where((e) => e != null && e.toString().isNotEmpty).join(' · '), style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
              ]),
            ),
          ])),
        if (widget.driver && r['rider_first_name'] != null)
          _card(Row(children: [
            Icon(Icons.person_outline, color: DropColors.mutedText(context)),
            const SizedBox(width: 10),
            Text('Passenger: ${r['rider_first_name']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DropColors.text(context))),
          ])),
        _card(Column(children: [
          for (final l in lines) DropReceiptRow(label: l['label'].toString(), amount: DropMoneyText(l['amount'], symbol: _sym(r))),
          if (!widget.driver) ...[
            if (fee > 0) DropReceiptRow(label: 'Cancellation fee', amount: Text(_m(r, fee))),
            Divider(height: 12, color: DropColors.hairline(context)),
            DropReceiptRow(label: 'Total', amount: Text(_m(r, r['total'])), bold: true),
          ] else ...[
            Divider(height: 12, color: DropColors.hairline(context)),
            DropReceiptRow(label: 'Fare', amount: Text(_m(r, r['fare']))),
            DropReceiptRow(label: 'DROP commission', amount: Text(_m(r, -DropMoney.toNum(r['commission'])))),
            Divider(height: 12, color: DropColors.hairline(context)),
            DropReceiptRow(label: 'Your earning', amount: Text(_m(r, r['earning'])), bold: true),
          ],
        ])),
        _card(Row(children: [
          Icon(_payLabel(r) == 'Wallet' ? Icons.account_balance_wallet_outlined : Icons.payments_outlined, color: DropColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.driver ? (cash ? 'Passenger paid cash. The commission was taken from your wallet.' : 'Paid from the passenger’s wallet. Your earning was added to your wallet.') : 'Paid with ${_payLabel(r).toLowerCase()}',
              style: TextStyle(fontSize: 14, color: DropColors.text(context)),
            ),
          ),
        ])),
        if (widget.driver) ...[
          DropActionButton(
            label: 'Add extra charge',
            icon: Icons.add_card,
            onPressed: () async {
              final sent = await showDropAddExtraSheet(context, rideId: widget.rideId);
              if (sent) _load();
            },
          ),
          const SizedBox(height: 10),
        ],
        DropActionButton(
          label: 'Copy receipt',
          icon: Icons.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _asText(r)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt copied')));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip receipt')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: DropColors.mutedText(context))),
                      const SizedBox(height: 16),
                      SizedBox(width: 200, child: DropActionButton(label: 'Try again', onPressed: _load)),
                    ]),
                  ),
                )
              : _body(_r!),
    );
  }
}
