import 'package:flutter/material.dart';

import '../design/drop_design.dart';
import 'drop_phone_field.dart';

/// A Nigerian bank, microfinance bank or mobile money operator.
class DropBank {
  const DropBank({required this.code, required this.name, required this.kind, this.logoUrl});

  factory DropBank.fromJson(Map<String, dynamic> j) =>
      DropBank(code: '${j['code']}', name: '${j['name']}', kind: '${j['kind']}', logoUrl: j['logo_url'] as String?);

  final String code;
  final String name;
  final String kind; // bank | mfb | mmo
  final String? logoUrl;

  String get kindLabel => kind == 'mmo' ? 'Mobile money' : (kind == 'mfb' ? 'Microfinance bank' : 'Bank');
}

/// Round bank logo; shows the first letter when the logo is missing or cannot load.
class DropBankLogo extends StatelessWidget {
  const DropBankLogo({super.key, required this.bank, this.size = 36});

  final DropBank bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: DropColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(bank.name.isEmpty ? '?' : bank.name[0], style: TextStyle(color: DropColors.primary, fontWeight: FontWeight.w800, fontSize: size * 0.42)),
    );
    final String? url = bank.logoUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(url, width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback, loadingBuilder: (c, child, p) => p == null ? child : fallback),
    );
  }
}

/// Opens a searchable A to Z list of banks and returns the one the person taps.
Future<DropBank?> pickDropBank(BuildContext context, List<DropBank> banks) {
  return showModalBottomSheet<DropBank>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DropColors.background(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DropRadius.card))),
    builder: (_) => _BankSheet(banks: banks),
  );
}

class _BankSheet extends StatefulWidget {
  const _BankSheet({required this.banks});

  final List<DropBank> banks;

  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final String q = _q.trim().toLowerCase();
    final List<DropBank> shown = widget.banks.where((b) => q.isEmpty || b.name.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: DropColors.hairline(context), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: TextStyle(color: DropColors.text(context)),
                decoration: dropInputDecoration(context, label: 'Search bank or wallet', prefix: const Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text('No match', style: TextStyle(color: DropColors.mutedText(context))))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final DropBank b = shown[i];
                        return ListTile(
                          leading: DropBankLogo(bank: b),
                          title: Text(b.name, style: TextStyle(color: DropColors.text(context), fontWeight: FontWeight.w600)),
                          subtitle: Text(b.kindLabel, style: TextStyle(color: DropColors.mutedText(context), fontSize: 12.5)),
                          onTap: () => Navigator.pop(context, b),
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
