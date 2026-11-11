
import '../drop/data/drop_countries.dart';
import '../drop/design/drop_design.dart';
import '../drop/services/drop_biometric.dart';
import '../drop/services/drop_session.dart';
import '../drop/widgets/drop_phone_field.dart';
import '../manage_imports.dart';

/// DROP passenger sign-up: first name, last name, phone number and a password. Email is optional
/// and the username is generated for you.
class SignUpScreen extends StatefulWidget {
  /// The old phone-OTP dialog still passes these; they are accepted and ignored.
  const SignUpScreen({super.key, this.countryCode, this.userName, this.socialLogin = false});

  final String? countryCode;
  final String? userName;
  final bool socialLogin;

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _first = TextEditingController();
  final TextEditingController _last = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  DropCountry _country = defaultDropCountry;
  bool _hidePassword = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    saveOneSignalPlayerId().then((_) {}).catchError((_) {});
  }

  Future<void> _submit() async {
    hideKeyboard(context);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final String id = '${_country.dial}${dropNationalNumber(_phone.text)}';
    final String pw = _password.text;
    try {
      await signUpApi({
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'contact_number': dropNationalNumber(_phone.text),
        'country_code': _country.dial,
        'email': _email.text.trim(),
        'password': pw,
        'user_type': RIDER,
        'player_id': sharedPref.getString(PLAYER_ID).validate(),
      });
      // The server created the account; log in to get the session.
      final res = await logInApi({'identifier': id, 'password': pw, 'player_id': sharedPref.getString(PLAYER_ID).validate(), 'user_type': RIDER});
      if (res.data == null) {
        toast(res.message.validate().isNotEmpty ? res.message : 'Account created. Please log in.');
        if (mounted) launchScreen(context, const SignInScreen(), isNewTask: true);
        return;
      }
      if (await DropBiometric.deviceSupported() && !await DropBiometric.isEnabled() && mounted) {
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

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle input = TextStyle(color: DropColors.text(context), fontSize: 16);
    return Scaffold(
      backgroundColor: DropColors.background(context),
      appBar: AppBar(
        backgroundColor: DropColors.background(context),
        elevation: 0,
        iconTheme: IconThemeData(color: DropColors.text(context)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DropSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: DropLogo(width: 150)),
                    const SizedBox(height: DropSpacing.lg),
                    Text('Create your account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DropColors.text(context))),
                    const SizedBox(height: 6),
                    Text('It takes less than a minute.', style: TextStyle(fontSize: 15, color: DropColors.mutedText(context))),
                    const SizedBox(height: DropSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _first,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            style: input,
                            decoration: dropInputDecoration(context, label: 'First name'),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: DropSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            controller: _last,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            style: input,
                            decoration: dropInputDecoration(context, label: 'Last name'),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DropSpacing.md),
                    DropPhoneField(
                      controller: _phone,
                      country: _country,
                      onCountryChanged: (c) => setState(() => _country = c),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: DropSpacing.md),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: input,
                      decoration: dropInputDecoration(context, label: 'Email (optional)', prefix: const Icon(Icons.mail_outline)),
                      validator: (v) {
                        final String t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: DropSpacing.md),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: input,
                      decoration: dropInputDecoration(
                        context,
                        label: 'Password',
                        prefix: const Icon(Icons.lock_outline),
                        suffix: IconButton(
                          icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
                    ),
                    const SizedBox(height: DropSpacing.md),
                    Text(
                      'By continuing you agree to the DROP Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: DropColors.mutedText(context)),
                    ),
                    const SizedBox(height: DropSpacing.md),
                    DropPrimaryButton(label: 'Create account', loading: _busy, onPressed: _submit),
                    const SizedBox(height: DropSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ', style: TextStyle(color: DropColors.mutedText(context))),
                        GestureDetector(
                          onTap: () => launchScreen(context, const SignInScreen(), pageRouteAnimation: PageRouteAnimation.Slide),
                          child: Text('Log in', style: TextStyle(color: DropColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: DropSpacing.xl),
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
