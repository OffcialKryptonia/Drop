import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../service/DriverApplicationApi.dart' show ApiFailure;
import '../../service/RideApi.dart';
import '../design/drop_design.dart';
import 'drop_phone_field.dart';

/// Asks accounts that have no email to add one, so they can reset a forgotten password.
/// Shown at most once a week when the user taps "Not now".
class DropEmailPrompt {
  DropEmailPrompt._();

  static const _snoozeKey = 'drop_email_prompt_until';
  static bool _shownThisRun = false;

  static Future<void> maybeShow(BuildContext context) async {
    if (_shownThisRun) return;
    _shownThisRun = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (DateTime.now().millisecondsSinceEpoch < (prefs.getInt(_snoozeKey) ?? 0)) return;
      final status = await RideApi.emailStatus();
      if (status['has_email'] == true || !context.mounted) return;
      final saved = await showDialog<bool>(context: context, builder: (_) => const _EmailDialog());
      if (saved != true) {
        await prefs.setInt(_snoozeKey, DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch);
      }
    } catch (_) {
      // Best effort: never get in the way of booking a ride.
    }
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog();

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RideApi.saveEmail(_email.text.trim(), _password.text);
      if (mounted) Navigator.pop(context, true);
      return;
    } on ApiFailure catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add your email'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('If you ever forget your password, we will send a reset code to this email.', style: TextStyle(color: DropColors.mutedText(context))),
          const SizedBox(height: DropSpacing.md),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: dropInputDecoration(context, label: 'Email', prefix: const Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: DropSpacing.sm),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: dropInputDecoration(context, label: 'Your password (to confirm)', prefix: const Icon(Icons.lock_outline)),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Not now')),
        TextButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
      ],
    );
  }
}
