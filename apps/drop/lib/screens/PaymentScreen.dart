import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../manage_imports.dart';
import '../model/VirtualAccountModel.dart';

/// Adding money to the wallet: bank transfer to the person's own account number (Pocketfi).
/// The wallet is credited automatically when the transfer arrives; nothing is paid inside the app.
/// Pops `true` so the calling screen refreshes its balance.
class PaymentScreen extends StatefulWidget {
  final num? amount;

  PaymentScreen({this.amount});

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  VirtualAccountData? account;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await getWalletVirtualAccount();
      account = r.data;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  void close() => Navigator.pop(context, true);

  void copy(String number) {
    Clipboard.setData(ClipboardData(text: number)).then((_) => toast(language.accountNumberCopied));
  }

  @override
  Widget build(BuildContext context) {
    final a = account;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(language.fundByTransfer, style: boldTextStyle(color: Colors.white)),
          backgroundColor: primaryColor,
          leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: close),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: loading
              ? Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
              : (a != null && a.accountNumber.validate().isNotEmpty)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.amount != null) Text('${widget.amount}', style: boldTextStyle(size: 22)),
                        SizedBox(height: 12),
                        if (a.bankName.validate().isNotEmpty) Text(a.bankName.validate().toUpperCase(), style: secondaryTextStyle(size: 12)),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: SelectableText(a.accountNumber.validate(), style: boldTextStyle(size: 28))),
                            IconButton(tooltip: language.copyAccountNumber, icon: Icon(Icons.copy, color: primaryColor), onPressed: () => copy(a.accountNumber.validate())),
                          ],
                        ),
                        if (a.accountName.validate().isNotEmpty) Text(a.accountName.validate(), style: primaryTextStyle()),
                        SizedBox(height: 16),
                        Text(language.transferHint, style: secondaryTextStyle()),
                        SizedBox(height: 24),
                        AppButtonWidget(text: language.copyAccountNumber, width: MediaQuery.of(context).size.width, onTap: () => copy(a.accountNumber.validate())),
                        SizedBox(height: 12),
                        AppButtonWidget(text: language.done, width: MediaQuery.of(context).size.width, color: Colors.grey.shade700, onTap: close),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 60),
                        Text((error ?? '').isEmpty ? language.gettingAccountNumber : error!, textAlign: TextAlign.center, style: secondaryTextStyle()),
                        SizedBox(height: 16),
                        AppButtonWidget(text: language.tryAgain, width: MediaQuery.of(context).size.width, onTap: load),
                      ],
                    ),
        ),
      ),
    );
  }
}
