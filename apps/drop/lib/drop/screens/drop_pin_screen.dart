import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mighty_core/utils/core_enum.dart';

import '../design/drop_design.dart';
import '../services/drop_api.dart';
import '../widgets/drop_phone_field.dart';

/// Create or change the 4-digit transaction PIN. If the old PIN is forgotten, the account
/// password proves it is you.
class DropPinScreen extends StatefulWidget {
  const DropPinScreen({super.key});

  @override
  State<DropPinScreen> createState() => _DropPinScreenState();
}

class _DropPinScreenState extends State<DropPinScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _loading = true;
  bool _hasPin = false;
  bool _usePassword = false;
  bool _hidePassword = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    dropApi('wallet/pin').then((r) {
      if (mounted) setState(() {
            _hasPin = r['has_pin'] == true;
            _loading = false;
          });
    }).catchError((Object e) {
      if (mounted) setState(() {
            _error = e.toString();
            _loading = false;
          });
    });
  }

  Future<void> _save() async {
    hideKeyboard(context);
    if (_hasPin && !_usePassword && _current.text.length != 4) return setState(() => _error = 'Enter your current PIN.');
    if (_hasPin && _usePassword && _password.text.isEmpty) return setState(() => _error = 'Enter your account password.');
    if (_new.text.length != 4) return setState(() => _error = 'Your new PIN must be 4 digits.');
    if (_new.text != _confirm.text) return setState(() => _error = 'The two new PINs do not match.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> body = {'pin': _new.text};
      if (_hasPin) {
        if (_usePassword) {
          body['password'] = _password.text;
        } else {
          body['current_pin'] = _current.text;
        }
      }
      final r = await dropApi('wallet/pin', method: HttpMethods.POST, request: body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['message']}')));
      Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _pinField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
      style: TextStyle(color: DropColors.text(context), fontSize: 20, letterSpacing: 8),
      decoration: dropInputDecoration(context, label: label, hint: '4 digits', prefix: const Icon(Icons.pin_outlined)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DropColors.background(context),
      appBar: AppBar(title: Text(_hasPin ? 'Change PIN' : 'Create PIN'), backgroundColor: DropColors.primary, foregroundColor: Colors.white, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(DropSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _hasPin ? 'Your PIN confirms every transfer you send.' : 'Create a 4-digit PIN. You will enter it every time you send money.',
                    style: TextStyle(color: DropColors.mutedText(context), fontSize: 15),
                  ),
                  const SizedBox(height: DropSpacing.lg),
                  if (_hasPin) ...[
                    if (!_usePassword)
                      _pinField(_current, 'Current PIN')
                    else
                      TextField(
                        controller: _password,
                        obscureText: _hidePassword,
                        style: TextStyle(color: DropColors.text(context), fontSize: 16),
                        decoration: dropInputDecoration(
                          context,
                          label: 'Account password',
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _usePassword = !_usePassword;
                          _error = null;
                        }),
                        child: Text(_usePassword ? 'Use my current PIN' : 'Forgot PIN? Use my password', style: TextStyle(color: DropColors.primary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                  const SizedBox(height: DropSpacing.sm),
                  _pinField(_new, 'New PIN'),
                  const SizedBox(height: DropSpacing.md),
                  _pinField(_confirm, 'Confirm new PIN'),
                  if (_error != null) ...[
                    const SizedBox(height: DropSpacing.md),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: DropSpacing.xl),
                  DropPrimaryButton(label: _hasPin ? 'Change PIN' : 'Create PIN', loading: _saving, onPressed: _save),
                ],
              ),
            ),
    );
  }
}
