import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/DriverApplicationApi.dart' show ApiFailure;
import '../../service/RideApi.dart';
import '../design/drop_design.dart';
import '../widgets/drop_phone_field.dart';

/// Forgot password: ask for a code by email, then choose a new password.
class DropForgotPasswordScreen extends StatefulWidget {
  const DropForgotPasswordScreen({super.key});

  @override
  State<DropForgotPasswordScreen> createState() => _DropForgotPasswordScreenState();
}

class _DropForgotPasswordScreenState extends State<DropForgotPasswordScreen> {
  final _id = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  bool _hide = true;
  String? _info;
  String? _error;

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } on ApiFailure catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendCode() async {
    if (_id.text.trim().isEmpty) {
      setState(() => _error = 'Enter your phone number, username or email.');
      return;
    }
    await _run(() async {
      final r = await RideApi.forgotPassword(_id.text.trim());
      _info = r['message']?.toString();
      _codeStep = true;
    });
  }

  Future<void> _reset() async {
    await _run(() async {
      final r = await RideApi.resetPassword(_id.text.trim(), _code.text.trim(), _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message']?.toString() ?? 'Password changed.')));
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DropColors.background(context),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: DropColors.text(context)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DropSpacing.lg, vertical: DropSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Reset your password', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DropColors.text(context))),
                  const SizedBox(height: 6),
                  Text(
                    _codeStep ? 'Enter the 6-digit code we emailed you and choose a new password.' : 'Enter your phone number, username or email. We will email you a 6-digit code.',
                    style: TextStyle(fontSize: 15, color: DropColors.mutedText(context)),
                  ),
                  const SizedBox(height: DropSpacing.lg),
                  TextFormField(
                    controller: _id,
                    enabled: !_codeStep,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: DropColors.text(context), fontSize: 16),
                    decoration: dropInputDecoration(context, label: 'Phone, username or email', prefix: const Icon(Icons.person_outline)),
                  ),
                  if (_codeStep) ...[
                    const SizedBox(height: DropSpacing.md),
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: DropColors.text(context), fontSize: 16, letterSpacing: 4),
                      decoration: dropInputDecoration(context, label: '6-digit code', prefix: const Icon(Icons.pin_outlined)),
                    ),
                    const SizedBox(height: DropSpacing.sm),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      style: TextStyle(color: DropColors.text(context), fontSize: 16),
                      decoration: dropInputDecoration(
                        context,
                        label: 'New password (8+ characters)',
                        prefix: const Icon(Icons.lock_outline),
                        suffix: IconButton(
                          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                  ],
                  if (_info != null && _error == null) ...[
                    const SizedBox(height: DropSpacing.md),
                    Text(_info!, style: TextStyle(color: DropColors.mutedText(context), fontSize: 13)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: DropSpacing.md),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
                  ],
                  const SizedBox(height: DropSpacing.md),
                  Text('Did support give you a temporary password? Do not enter it here. Go back and type it on the Log in screen, then change it from your profile.', style: TextStyle(color: DropColors.mutedText(context), fontSize: 12)),
                  const SizedBox(height: DropSpacing.lg),
                  DropPrimaryButton(label: _codeStep ? 'Change password' : 'Send code', loading: _busy, onPressed: _codeStep ? _reset : _sendCode),
                  if (_codeStep)
                    TextButton(
                      onPressed: _busy ? null : _sendCode,
                      child: Text('Send a new code', style: TextStyle(color: DropColors.primary)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
