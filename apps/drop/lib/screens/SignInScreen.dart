import 'package:flutter/material.dart';

import '../drop/data/drop_countries.dart';
import '../drop/design/drop_design.dart';
import '../drop/services/drop_biometric.dart';
import '../drop/services/drop_session.dart';
import '../drop/widgets/drop_phone_field.dart';
import '../manage_imports.dart';
import 'SignUpScreen.dart';

/// DROP log in: phone number or username, with a password, and fingerprint where available.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  DropCountry _country = defaultDropCountry;
  bool _usePhone = true;
  bool _hidePassword = true;
  bool _busy = false;
  bool _bioReady = false;

  @override
  void initState() {
    super.initState();
    saveOneSignalPlayerId().then((_) {}).catchError((_) {});
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final bool ready = await DropBiometric.deviceSupported() && await DropBiometric.isEnabled();
    if (!mounted) return;
    setState(() => _bioReady = ready);
  }

  String get _identifier => _usePhone ? '${_country.dial}${dropNationalNumber(_phone.text)}' : _username.text.trim();

  Future<void> _login({String? identifier, String? password, bool offerBiometric = true}) async {
    hideKeyboard(context);
    if (identifier == null && !_form.currentState!.validate()) return;
    final String id = identifier ?? _identifier;
    final String pw = password ?? _password.text;
    setState(() => _busy = true);
    try {
      final res = await logInApi({
        'identifier': id,
        'password': pw,
        'player_id': sharedPref.getString(PLAYER_ID).validate(),
        'user_type': RIDER,
      });
      if (res.data == null) {
        toast(res.message.validate().isNotEmpty ? res.message : 'Wrong phone number, username or password');
        return;
      }
      if (offerBiometric && await DropBiometric.deviceSupported() && !await DropBiometric.isEnabled() && mounted) {
        final bool? yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Log in with fingerprint?'),
            content: const Text('Next time you can open DROP with your fingerprint instead of typing your password.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn on')),
            ],
          ),
        );
        if (yes == true) await DropBiometric.enable(identifier: id, password: pw);
      }
      if (!mounted) return;
      await dropFinishSignIn(context, res.data!, pw);
    } catch (e) {
      toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fingerprint() async {
    final saved = await DropBiometric.unlock();
    if (saved == null) return;
    await _login(identifier: saved.identifier, password: saved.password, offerBiometric: false);
  }

  @override
  void dispose() {
    _phone.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DropColors.background(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DropSpacing.lg, vertical: DropSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: DropLogo(width: 170)),
                    const SizedBox(height: DropSpacing.xl),
                    Text('Welcome back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DropColors.text(context))),
                    const SizedBox(height: 6),
                    Text('Log in to book your next ride.', style: TextStyle(fontSize: 15, color: DropColors.mutedText(context))),
                    const SizedBox(height: DropSpacing.lg),
                    _Toggle(usePhone: _usePhone, onChanged: (v) => setState(() => _usePhone = v)),
                    const SizedBox(height: DropSpacing.md),
                    if (_usePhone)
                      DropPhoneField(
                        controller: _phone,
                        country: _country,
                        onCountryChanged: (c) => setState(() => _country = c),
                        textInputAction: TextInputAction.next,
                      )
                    else
                      TextFormField(
                        controller: _username,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        style: TextStyle(color: DropColors.text(context), fontSize: 16),
                        decoration: dropInputDecoration(context, label: 'Username', prefix: const Icon(Icons.alternate_email)),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your username' : null,
                      ),
                    const SizedBox(height: DropSpacing.md),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      style: TextStyle(color: DropColors.text(context), fontSize: 16),
                      decoration: dropInputDecoration(
                        context,
                        label: 'Password',
                        prefix: const Icon(Icons.lock_outline),
                        suffix: IconButton(
                          icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: DropSpacing.lg),
                    DropPrimaryButton(label: 'Log in', loading: _busy, onPressed: _login),
                    if (_bioReady) ...[
                      const SizedBox(height: DropSpacing.md),
                      DropSecondaryButton(label: 'Use fingerprint', onPressed: _busy ? null : _fingerprint),
                    ],
                    const SizedBox(height: DropSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("New to DROP? ", style: TextStyle(color: DropColors.mutedText(context))),
                        GestureDetector(
                          onTap: () => launchScreen(context, const SignUpScreen(), pageRouteAnimation: PageRouteAnimation.Slide),
                          child: Text('Create an account', style: TextStyle(color: DropColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.usePhone, required this.onChanged});

  final bool usePhone;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? DropColors.background(context) : Colors.transparent,
                borderRadius: BorderRadius.circular(DropRadius.field - 2),
                boxShadow: selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))] : null,
              ),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? DropColors.primary : DropColors.mutedText(context))),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(DropRadius.field)),
      child: Row(children: [tab('Phone', usePhone, () => onChanged(true)), tab('Username', !usePhone, () => onChanged(false))]),
    );
  }
}
