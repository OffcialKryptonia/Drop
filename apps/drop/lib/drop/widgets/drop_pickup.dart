import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/DriverApplicationApi.dart' show ApiFailure;
import '../../service/RideApi.dart';
import '../design/drop_design.dart';
import 'drop_ride_ui.dart';

/// Passenger: the pickup code, big and easy to read out. Shown until the driver has verified it.
class DropPickupCodeCard extends StatelessWidget {
  const DropPickupCodeCard({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: DropColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DropRadius.card),
        border: Border.all(color: DropColors.primary.withValues(alpha: 0.35)),
      ),
      child: Semantics(
        label: 'Your pickup code is ${code.split('').join(' ')}',
        child: Column(children: [
          Text('Your pickup code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DropColors.mutedText(context))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final d in code.split(''))
              Container(
                width: 46,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(12)),
                child: Text(d, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: DropColors.text(context))),
              ),
          ]),
          const SizedBox(height: 8),
          Text('Tell this code to your driver when you meet. Do not share it with anyone else.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.3, color: DropColors.mutedText(context))),
        ]),
      ),
    );
  }
}

/// Driver: enter the passenger's four-digit code. Returns true once the server accepts it.
Future<bool> showDropVerifyPickupSheet(BuildContext context, {required int rideId}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => _VerifyPickupSheet(rideId: rideId),
  );
  return ok == true;
}

class _VerifyPickupSheet extends StatefulWidget {
  const _VerifyPickupSheet({required this.rideId});
  final int rideId;
  @override
  State<_VerifyPickupSheet> createState() => _VerifyPickupSheetState();
}

class _VerifyPickupSheetState extends State<_VerifyPickupSheet> {
  final _nodes = List.generate(4, (_) => FocusNode());
  final _ctrls = List.generate(4, (_) => TextEditingController());
  bool _busy = false;
  String? _error;

  String get _code => _ctrls.map((c) => c.text).join();

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _typed(int i, String v) {
    if (v.length > 1) {
      // A pasted code fills every box.
      final digits = v.replaceAll(RegExp(r'\D'), '');
      for (var k = 0; k < 4; k++) {
        _ctrls[k].text = k < digits.length ? digits[k] : '';
      }
      if (digits.length >= 4) _nodes[3].requestFocus();
      setState(() => _error = null);
      return;
    }
    setState(() => _error = null);
    if (v.isNotEmpty && i < 3) _nodes[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
  }

  Future<void> _verify() async {
    if (_code.length != 4) {
      setState(() => _error = 'Enter all four digits.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RideApi.verifyPickup(widget.rideId, _code);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      HapticFeedback.heavyImpact();
      for (final c in _ctrls) {
        c.clear();
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
        _nodes[0].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: DropSheet(
        maxHeightFactor: 0.8,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Verify passenger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DropColors.text(context))),
            const SizedBox(height: 6),
            Text('Ask the passenger for their four-digit pickup code and enter it here.',
                style: TextStyle(fontSize: 15, height: 1.35, color: DropColors.mutedText(context))),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 58,
                  height: 68,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: TextField(
                    controller: _ctrls[i],
                    focusNode: _nodes[i],
                    autofocus: i == 0,
                    enabled: !_busy,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: DropColors.surface(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: DropColors.primary, width: 2)),
                    ),
                    onChanged: (v) => _typed(i, v),
                    onSubmitted: (_) => _verify(),
                  ),
                ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 18),
            DropActionButton(label: 'Verify pickup', primary: true, loading: _busy, onPressed: _busy ? null : _verify),
          ]),
        ),
      ),
    );
  }
}
