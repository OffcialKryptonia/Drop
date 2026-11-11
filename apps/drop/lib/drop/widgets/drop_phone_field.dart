import 'package:flutter/material.dart';

import '../data/drop_countries.dart';
import '../design/drop_design.dart';

/// Shared text field look for the login and sign-up screens.
InputDecoration dropInputDecoration(BuildContext context, {required String label, Widget? prefix, Widget? suffix, String? hint}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(DropRadius.field), borderSide: BorderSide(color: color, width: width));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: DropColors.surface(context),
    labelStyle: TextStyle(color: DropColors.mutedText(context)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: border(DropColors.hairline(context)),
    focusedBorder: border(DropColors.primary, 1.6),
    errorBorder: border(Colors.redAccent),
    focusedErrorBorder: border(Colors.redAccent, 1.6),
  );
}

/// Phone number input with a Nigeria-first country picker.
class DropPhoneField extends StatefulWidget {
  const DropPhoneField({super.key, required this.controller, required this.country, required this.onCountryChanged, this.textInputAction, this.onSubmitted});

  final TextEditingController controller;
  final DropCountry country;
  final ValueChanged<DropCountry> onCountryChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<DropPhoneField> createState() => _DropPhoneFieldState();
}

class _DropPhoneFieldState extends State<DropPhoneField> {
  Future<void> _pick() async {
    final DropCountry? chosen = await showModalBottomSheet<DropCountry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DropColors.background(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DropRadius.card))),
      builder: (_) => const _CountrySheet(),
    );
    if (chosen != null) widget.onCountryChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final DropCountry c = widget.country;
    return TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      style: TextStyle(color: DropColors.text(context), fontSize: 16),
      decoration: dropInputDecoration(
        context,
        label: 'Phone number',
        hint: c.iso == 'NG' ? '801 234 5678' : null,
        prefix: InkWell(
          borderRadius: BorderRadius.circular(DropRadius.field),
          onTap: _pick,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                Text(c.dial, style: TextStyle(color: DropColors.text(context), fontWeight: FontWeight.w600)),
                Icon(Icons.keyboard_arrow_down_rounded, color: DropColors.mutedText(context)),
              ],
            ),
          ),
        ),
      ),
      validator: (value) {
        final String n = dropNationalNumber(value ?? '');
        if (n.isEmpty) return 'Enter your phone number';
        if (n.length < c.minDigits || n.length > c.maxDigits) return 'Enter a valid ${c.name} phone number';
        return null;
      },
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet();

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String q = _query.trim().toLowerCase();
    final List<DropCountry> shown = dropCountries.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.dial.contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: DropColors.hairline(context), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: DropColors.text(context)),
                decoration: dropInputDecoration(context, label: 'Search country', prefix: const Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final DropCountry c = shown[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(c.name, style: TextStyle(color: DropColors.text(context), fontWeight: FontWeight.w600)),
                    trailing: Text(c.dial, style: TextStyle(color: DropColors.mutedText(context))),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
