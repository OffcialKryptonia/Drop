import 'package:drop/service/DriverApplicationApi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/Colors.dart';
import 'BankInfoScreen.dart';

/// Withdraw and payout history for drivers. Balance, smallest payout, bank account and history come from one call.
/// The amount leaves the wallet when the request is made; DROP pays the bank account and marks it paid.
class DriverWithdrawScreen extends StatefulWidget {
  const DriverWithdrawScreen({super.key});

  @override
  State<DriverWithdrawScreen> createState() => _DriverWithdrawScreenState();
}

class _DriverWithdrawScreenState extends State<DriverWithdrawScreen> {
  final TextEditingController amount = TextEditingController();
  Map<String, dynamic> d = {};
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = d.isEmpty;
      error = null;
    });
    try {
      d = await DriverApplicationApi.payouts();
    } on ApiFailure catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);

  String _money(num v) {
    final t = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    final p = t.split('.');
    final whole = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    final sym = (d['currency'] ?? 'NGN') == 'NGN' ? '₦' : '${d['currency']} ';
    return '$sym$whole${p.length > 1 ? '.${p[1]}' : ''}';
  }

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    final v = num.tryParse(amount.text.trim());
    final min = _n(d['min_amount']);
    if (v == null || v <= 0) return _say('Enter an amount.');
    if (v < min) return _say('The smallest payout is ${_money(min)}.');
    if (v > _n(d['balance'])) return _say('Your wallet balance is lower than this amount.');
    if (sending) return;
    setState(() => sending = true);
    try {
      final msg = await DriverApplicationApi.requestPayout(v);
      amount.clear();
      _say(msg);
      await _load();
    } on ApiFailure catch (e) {
      _say(e.message);
    }
    if (mounted) setState(() => sending = false);
  }

  Color _statusColor(String s) => s == 'paid' ? Colors.green : (s == 'declined' ? Colors.red : Colors.orange);

  @override
  Widget build(BuildContext context) {
    final bank = d['bank'] is Map ? Map<String, dynamic>.from(d['bank'] as Map) : null;
    final history = d['history'] is List ? (d['history'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    final enabled = d['enabled'] != false;
    final pending = d['has_pending'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw', style: TextStyle(color: Colors.white))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && d.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Available to withdraw', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(_money(_n(d['balance'])), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (bank == null)
                      _notice('Add your bank account before you withdraw.', action: 'Add bank info', onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BankInfoScreen()));
                        _load();
                      })
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.account_balance_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${bank['bank_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${bank['account_number'] ?? ''}  ·  ${bank['account_name'] ?? ''}', style: TextStyle(color: Colors.grey.shade700)),
                            ]),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 16),
                    if (!enabled)
                      _notice('Payouts are paused for now. Please try again later.')
                    else if (pending)
                      _notice('You have a payout waiting to be paid. You can ask for another once it is paid.')
                    else if (bank != null) ...[
                      TextField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(labelText: 'Amount', helperText: 'Smallest payout ${_money(_n(d['min_amount']))}', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: sending ? null : _send,
                          child: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Request payout'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text('Payout history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (history.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('No payouts yet.', style: TextStyle(color: Colors.grey.shade700))),
                    for (final h in history)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_money(_n(h['amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text((h['created_at'] ?? '').toString().split('T').first),
                        trailing: Text('${h['status_text'] ?? ''}', style: TextStyle(color: _statusColor('${h['status']}'), fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
    );
  }

  Widget _notice(String text, {String? action, VoidCallback? onTap}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Text(text)),
          if (action != null) TextButton(onPressed: onTap, child: Text(action)),
        ]),
      );
}
