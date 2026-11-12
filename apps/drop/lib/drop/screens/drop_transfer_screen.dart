import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mighty_core/utils/core_enum.dart';

import '../../manage_imports.dart';
import '../design/drop_design.dart';
import '../services/drop_api.dart';
import '../services/drop_money.dart';
import 'drop_pin_screen.dart';
import '../widgets/drop_phone_field.dart';

/// Send money from your DROP wallet to another passenger using their username, confirmed with a PIN.
class DropTransferScreen extends StatefulWidget {
  const DropTransferScreen({super.key, required this.balance});

  final double balance;

  @override
  State<DropTransferScreen> createState() => _DropTransferScreenState();
}

class _DropTransferScreenState extends State<DropTransferScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();

  String? _recipientName;
  String? _recipientUsername;
  bool _finding = false;
  bool _sending = false;
  String? _error;
  double _min = 100;

  @override
  void initState() {
    super.initState();
    dropApi('wallet/transfer/settings').then((s) {
      if (mounted) setState(() => _min = (s['min'] as num?)?.toDouble() ?? 100);
    }).catchError((_) {});
  }

  Future<void> _find() async {
    final String u = _username.text.trim().replaceFirst('@', '');
    if (u.isEmpty) return;
    setState(() {
      _finding = true;
      _recipientName = null;
      _error = null;
    });
    try {
      final r = await dropApi('wallet/transfer/recipient?username=${Uri.encodeQueryComponent(u)}');
      if (!mounted) return;
      if (r['found'] == true) {
        _recipientName = '${r['name']}';
        _recipientUsername = '${r['username']}';
      } else {
        _error = 'We could not find that username.';
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _finding = false);
  }

  /// Asks for a 4-digit PIN in a small dialog. Returns null if cancelled.
  Future<String?> _askPin(String title, {String? subtitle, bool forgot = false}) {
    final TextEditingController c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(subtitle)),
            TextField(
              controller: c,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              style: const TextStyle(fontSize: 28, letterSpacing: 12),
              decoration: const InputDecoration(counterText: '', hintText: '••••'),
              onChanged: (v) {
                if (v.length == 4) Navigator.pop(ctx, v);
              },
            ),
          ],
        ),
        actions: [
          if (forgot)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DropPinScreen()));
              },
              child: const Text('Forgot PIN?'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  /// First transfer: make the person create a PIN (typed twice).
  Future<bool> _createPin() async {
    final String? first = await _askPin('Create a transaction PIN', subtitle: 'You will enter this PIN every time you send money.');
    if (first == null) return false;
    final String? again = await _askPin('Confirm your PIN');
    if (again == null) return false;
    if (first != again) {
      setState(() => _error = 'The two PINs did not match. Try again.');
      return false;
    }
    try {
      await dropApi('wallet/pin', method: HttpMethods.POST, request: {'pin': first});
      return true;
    } catch (e) {
      setState(() => _error = e.toString());
      return false;
    }
  }

  Future<void> _send() async {
    hideKeyboard(context);
    final double? amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (_recipientUsername == null) return setState(() => _error = 'Find the person you want to pay first.');
    if (amount == null || amount < _min) return setState(() => _error = 'Enter at least ${DropMoney.symbol}${_min.toStringAsFixed(0)}.');
    if (amount > widget.balance) return setState(() => _error = 'You do not have enough balance for this.');
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final pinInfo = await dropApi('wallet/pin');
      if (pinInfo['has_pin'] != true && !await _createPin()) {
        if (mounted) setState(() => _sending = false);
        return;
      }
      final String? pin = await _askPin('Enter your PIN', forgot: true, subtitle: 'Send ${DropMoney.symbol}${amount.toStringAsFixed(2)} to @$_recipientUsername');
      if (pin == null) {
        if (mounted) setState(() => _sending = false);
        return;
      }
      final r = await dropApi('wallet/transfer', method: HttpMethods.POST, request: {
        'username': _recipientUsername,
        'amount': amount,
        'pin': pin,
        'note': _note.text.trim(),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: DropColors.success, size: 48),
          title: const Text('Money sent'),
          content: Text('${r['message']}\nNew balance: ${DropMoney.symbol}${(r['balance'] as num).toStringAsFixed(2)}'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _username.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle input = TextStyle(color: DropColors.text(context), fontSize: 16);
    return Scaffold(
      backgroundColor: DropColors.background(context),
      appBar: AppBar(
        title: const Text('Send money'),
        backgroundColor: DropColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DropPinScreen())),
            child: const Text('PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DropSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Help a friend pay for a trip. Money leaves your wallet straight away.', style: TextStyle(color: DropColors.mutedText(context), fontSize: 15)),
            const SizedBox(height: DropSpacing.sm),
            Text('Available: ${DropMoney.symbol}${widget.balance.toStringAsFixed(2)}', style: TextStyle(color: DropColors.text(context), fontWeight: FontWeight.w700)),
            const SizedBox(height: DropSpacing.lg),
            TextField(
              controller: _username,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              onChanged: (_) => setState(() {
                _recipientName = null;
                _recipientUsername = null;
              }),
              style: input,
              decoration: dropInputDecoration(
                context,
                label: "Recipient's username",
                prefix: const Icon(Icons.alternate_email),
                suffix: _finding
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : TextButton(onPressed: _find, child: Text('Find', style: TextStyle(color: DropColors.primary, fontWeight: FontWeight.w700))),
              ),
            ),
            if (_recipientName != null) ...[
              const SizedBox(height: DropSpacing.sm),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: DropColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(DropRadius.field)),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: DropColors.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text('$_recipientName  ·  @$_recipientUsername', style: TextStyle(color: DropColors.text(context), fontWeight: FontWeight.w700))),
                ]),
              ),
            ],
            const SizedBox(height: DropSpacing.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: input,
              decoration: dropInputDecoration(context, label: 'Amount', prefix: Padding(padding: const EdgeInsets.all(14), child: Text(DropMoney.symbol, style: input))),
            ),
            const SizedBox(height: DropSpacing.md),
            TextField(
              controller: _note,
              maxLength: 140,
              style: input,
              decoration: dropInputDecoration(context, label: 'Note (optional)', hint: 'e.g. For your ride home'),
            ),
            if (_error != null) ...[
              const SizedBox(height: DropSpacing.sm),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: DropSpacing.lg),
            DropPrimaryButton(label: 'Continue', loading: _sending, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
