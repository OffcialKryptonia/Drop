import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mighty_core/utils/core_enum.dart';

import '../../drop/design/drop_design.dart';
import '../../drop/services/drop_api.dart';
import '../../drop/widgets/drop_bank_picker.dart';
import '../../drop/widgets/drop_phone_field.dart';

/// Where a driver is paid: a Nigerian bank, microfinance bank or mobile money account.
/// The account name is looked up automatically; the driver only confirms it.
class BankInfoScreen extends StatefulWidget {
  @override
  BankInfoScreenState createState() => BankInfoScreenState();
}

class BankInfoScreenState extends State<BankInfoScreen> {
  final TextEditingController _account = TextEditingController();
  final TextEditingController _typedName = TextEditingController();

  List<DropBank> _banks = [];
  DropBank? _bank;
  String? _resolvedName; // from the bank lookup
  bool _lookupUnavailable = false; // lookup is not set up yet: the driver types the name
  bool _loading = true;
  bool _checking = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final banksRes = await dropApi('banks');
      _banks = ((banksRes['data'] as List?) ?? []).map((e) => DropBank.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final mine = await dropApi('bank/account');
      final data = mine['data'];
      if (data is Map) {
        for (final DropBank b in _banks) {
          if (b.code == '${data['bank_code']}') _bank = b;
        }
        _account.text = '${data['account_number'] ?? ''}';
        _resolvedName = data['verified'] == true ? '${data['account_name']}' : null;
        if (_resolvedName == null) _typedName.text = '${data['account_name'] ?? ''}';
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _lookup() async {
    final DropBank? bank = _bank;
    final String number = _account.text.trim();
    if (bank == null || number.length != 10) return;
    setState(() {
      _checking = true;
      _resolvedName = null;
      _error = null;
    });
    try {
      final r = await dropApi('bank/resolve', method: HttpMethods.POST, request: {'bank_code': bank.code, 'account_number': number});
      if (!mounted) return;
      if (r['resolved'] == true) {
        _resolvedName = '${r['account_name']}';
        _lookupUnavailable = false;
      } else if (r['reason'] == 'not_configured') {
        _lookupUnavailable = true;
      } else {
        _error = 'We could not find this account. Check the bank and number.';
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _save() async {
    final DropBank? bank = _bank;
    if (bank == null) return setState(() => _error = 'Choose your bank.');
    if (_account.text.trim().length != 10) return setState(() => _error = 'Enter the 10-digit account number.');
    if (_resolvedName == null && _typedName.text.trim().isEmpty) return setState(() => _error = 'Enter the account name.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await dropApi('bank/account', method: HttpMethods.POST, request: {
        'bank_code': bank.code,
        'account_number': _account.text.trim(),
        'account_name': _resolvedName ?? _typedName.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank account saved')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _account.dispose();
    _typedName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle input = TextStyle(color: DropColors.text(context), fontSize: 16);
    return Scaffold(
      backgroundColor: DropColors.background(context),
      appBar: AppBar(
        title: const Text('Payout account'),
        backgroundColor: DropColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(DropSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your earnings are paid to this account.', style: TextStyle(color: DropColors.mutedText(context), fontSize: 15)),
                  const SizedBox(height: DropSpacing.lg),
                  InkWell(
                    borderRadius: BorderRadius.circular(DropRadius.field),
                    onTap: () async {
                      final DropBank? b = await pickDropBank(context, _banks);
                      if (b == null) return;
                      setState(() {
                        _bank = b;
                        _resolvedName = null;
                        _error = null;
                      });
                      _lookup();
                    },
                    child: InputDecorator(
                      decoration: dropInputDecoration(context, label: 'Bank', suffix: const Icon(Icons.keyboard_arrow_down_rounded)),
                      child: _bank == null
                          ? Text('Choose bank or wallet', style: TextStyle(color: DropColors.mutedText(context), fontSize: 16))
                          : Row(children: [DropBankLogo(bank: _bank!, size: 28), const SizedBox(width: 10), Expanded(child: Text(_bank!.name, style: input))]),
                    ),
                  ),
                  const SizedBox(height: DropSpacing.md),
                  TextField(
                    controller: _account,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: input,
                    onChanged: (v) {
                      if (_resolvedName != null) setState(() => _resolvedName = null);
                      if (v.length == 10) _lookup();
                    },
                    decoration: dropInputDecoration(context, label: 'Account number', hint: '10 digits'),
                  ),
                  const SizedBox(height: DropSpacing.md),
                  if (_checking)
                    Row(children: [
                      const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Checking account…', style: TextStyle(color: DropColors.mutedText(context))),
                    ])
                  else if (_resolvedName != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: DropColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(DropRadius.field)),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: DropColors.success),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_resolvedName!, style: TextStyle(color: DropColors.text(context), fontWeight: FontWeight.w700))),
                      ]),
                    )
                  else if (_lookupUnavailable)
                    TextField(controller: _typedName, textCapitalization: TextCapitalization.words, style: input, decoration: dropInputDecoration(context, label: 'Account name', hint: 'Exactly as on your account')),
                  if (_error != null) ...[
                    const SizedBox(height: DropSpacing.md),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: DropSpacing.xl),
                  DropPrimaryButton(label: 'Save account', loading: _saving, onPressed: _save),
                ],
              ),
            ),
    );
  }
}
