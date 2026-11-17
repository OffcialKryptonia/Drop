import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:drop/driver/screens/PaymentScreen.dart';
import 'package:drop/driver/screens/WithDrawScreen.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

import 'package:drop/drop/design/drop_design.dart';
import 'package:drop/drop/widgets/drop_money.dart';
import 'package:drop/drop/widgets/drop_ride_ui.dart';
import 'package:drop/service/DriverApplicationApi.dart';

import '../main.dart';
import '../network/RestApis.dart';
import '../model/UserDetailModel.dart';
import '../model/VirtualAccountModel.dart';
import '../model/WalletListModel.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';

class WalletScreen extends StatefulWidget {
  @override
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController addMoneyController = TextEditingController();
  ScrollController scrollController = ScrollController();
  int currentPage = 1;
  int totalPage = 1;

  int currentIndex = -1;

  List<WalletModel> walletData = [];

  num totalAmount = 0;

  UserBankAccount? userBankAccount;

  // Bank transfer top-up: the driver's own account number.
  VirtualAccountData? virtualAccount;
  bool accountLoading = true;
  String? accountError;
  bool accountUnavailable = false; // feature not switched on yet: show a calm note instead of an error
  num? minimumBalance; // balance needed to go online, from /driver/status

  @override
  void initState() {
    super.initState();
    init();
    scrollController.addListener(() {
      if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
        if (currentPage < totalPage) {
          appStore.setLoading(true);
          currentPage++;
          setState(() {});

          init();
        }
      }
    });
    afterBuildCreated(() => appStore.setLoading(true));
  }

  void init() async {
    getBankDetail();
    getWalletData();
    if (currentPage == 1) {
      loadVirtualAccount();
      loadMinimum();
    }
  }

  Future<void> loadMinimum() async {
    try {
      final r = await DriverApplicationApi.driverStatus();
      final w = r['wallet'] ?? (r['data'] is Map ? r['data']['wallet'] : null);
      if (w is Map && w['minimum'] != null) {
        minimumBalance = DropMoney.toNum(w['minimum']);
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> loadVirtualAccount() async {
    if (virtualAccount != null) return;
    accountLoading = true;
    accountError = null;
    setState(() {});
    await getWalletVirtualAccount().then((value) {
      virtualAccount = value.data;
      accountLoading = false;
      setState(() {});
    }).catchError((error) {
      accountLoading = false;
      final text = error.toString();
      final lower = text.toLowerCase();
      if (lower.contains('not available') || lower.contains('unavailable')) {
        accountUnavailable = true;
      } else {
        accountError = text;
      }
      setState(() {});
    });
  }

  Widget _copyAccount(String number) => DropActionButton(
        label: language.copyAccountNumber,
        icon: Icons.copy,
        onPressed: () => Clipboard.setData(ClipboardData(text: number)).then((_) => toast(language.accountNumberCopied)),
      );

  Widget bankTransferCard() {
    final account = virtualAccount;
    final hasAccount = account != null && account.accountNumber.validate().isNotEmpty;
    Widget body;
    if (accountLoading) {
      body = Row(children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Text(language.gettingAccountNumber, style: TextStyle(color: DropColors.mutedText(context)))),
      ]);
    } else if (hasAccount) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (account.bankName.validate().isNotEmpty) Text(account.bankName.validate().toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: DropColors.mutedText(context))),
        const SizedBox(height: 4),
        SelectableText(account.accountNumber.validate(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: DropColors.text(context))),
        if (account.accountName.validate().isNotEmpty) Text(account.accountName.validate(), style: TextStyle(fontSize: 15, color: DropColors.text(context))),
        const SizedBox(height: 8),
        Text(language.transferHint, style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
        const SizedBox(height: 12),
        _copyAccount(account.accountNumber.validate()),
      ]);
    } else if (accountUnavailable) {
      body = Text('Bank transfer top-up is not available yet. You can still add money with the button above.', style: TextStyle(fontSize: 14, color: DropColors.mutedText(context)));
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('We could not load your account number. Check your connection and try again.', style: TextStyle(fontSize: 14, color: DropColors.mutedText(context))),
        const SizedBox(height: 12),
        DropActionButton(label: language.tryAgain, onPressed: () => loadVirtualAccount()),
      ]);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: DropColors.hairline(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance, color: DropColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(language.fundByTransfer, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DropColors.text(context)))),
        ]),
        const SizedBox(height: 12),
        body,
      ]),
    );
  }

  /// The balance card says what the number means, and offers the one action that fits it.
  Widget balanceCard() {
    final negative = totalAmount < -0.005;
    final zero = totalAmount.abs() <= 0.005;
    final label = negative ? 'You owe DROP' : (zero ? 'No balance' : language.availableBalance);
    final note = negative ? 'Commission on cash trips. Pay it to keep going online.' : (zero ? 'Add money to cover DROP commission on cash trips.' : null);
    final bg = negative ? const Color(0xFFB3261E) : DropColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: DropMoneyText(totalAmount, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900))),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
        ],
        if (minimumBalance != null) ...[
          const SizedBox(height: 8),
          Text('Minimum balance to go online: ${DropMoney.format(minimumBalance)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DropRadius.button))),
            onPressed: _showAddMoney,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(negative ? 'Pay commission' : language.addMoney, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ),
        ),
      ]),
    );
  }

  String _rowTitle(WalletModel d) {
    switch ((d.transactionType ?? '').toLowerCase()) {
      case 'topup':
        return 'Wallet top-up';
      case 'commission':
        return 'DROP commission \u00B7 cash trip';
      case 'ride_earning':
        return 'Trip earning';
      case 'transfer_in':
        return 'Money received';
      case 'transfer_out':
        return 'Money sent';
      case 'withdrawal':
        return 'Withdrawal';
      case 'refund':
        return 'Refund';
      case 'paymyride':
        return 'PayMyRide';
      case 'adjustment':
        return 'Adjustment by DROP';
      default:
        return d.type == DEBIT ? language.moneyDebit : language.moneyDeposited;
    }
  }

  String _dayLabel(String? raw) {
    final dt = DateTime.tryParse(raw ?? '')?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final diff = d0.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(dt);
  }

  Widget _txRow(WalletModel d) {
    final credit = d.type == CREDIT;
    final color = credit ? DropColors.success : Colors.red;
    final time = DateTime.tryParse(d.createdAt ?? '')?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.12), child: Icon(credit ? Icons.arrow_downward : Icons.arrow_upward, size: 20, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_rowTitle(d), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DropColors.text(context))),
            if (time != null) Text(DateFormat('hh:mm a').format(time), style: TextStyle(fontSize: 12, color: DropColors.mutedText(context))),
          ]),
        ),
        const SizedBox(width: 8),
        DropMoneyText(credit ? (d.amount ?? 0) : -(d.amount ?? 0), signed: true, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  List<Widget> _transactions() {
    final out = <Widget>[];
    String? last;
    for (final d in walletData) {
      final day = _dayLabel(d.createdAt);
      if (day != last) {
        out.add(Padding(padding: const EdgeInsets.only(top: 12, bottom: 2), child: Text(day, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: DropColors.mutedText(context)))));
        last = day;
      }
      out.add(_txRow(d));
    }
    return out;
  }

  void _showAddMoney() {
    showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius))),
                    builder: (_) {
                      return Form(
                        key: formKey,
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter setState) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(language.addMoney, style: boldTextStyle()),
                                        CloseButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            addMoneyController.clear();
                                            currentIndex = -1;
                                          },
                                        )
                                      ],
                                    ),
                                    AppTextField(
                                      controller: addMoneyController,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                      ],
                                      textFieldType: TextFieldType.PHONE,
                                      keyboardType: TextInputType.number,
                                      errorThisFieldRequired: language.thisFieldRequired,
                                      onChanged: (val) {
                                        //
                                      },
                                      validator: (String? val) {
                                        if (appStore.minAmountToAdd != null && num.parse(val!) < appStore.minAmountToAdd!) {
                                          // addMoneyController.text = appStore.minAmountToAdd.toString();
                                          addMoneyController.selection = TextSelection.fromPosition(TextPosition(offset: appStore.minAmountToAdd.toString().length));
                                          return "${language.minimum} ${appStore.minAmountToAdd} ${language.required}";
                                        } else if (appStore.maxAmountToAdd != null && num.parse(val!) > appStore.maxAmountToAdd!) {
                                          // addMoneyController.text = appStore.maxAmountToAdd.toString();
                                          addMoneyController.selection = TextSelection.fromPosition(TextPosition(offset: appStore.maxAmountToAdd.toString().length));
                                          return "${language.maximum} ${appStore.maxAmountToAdd} ${language.required}";
                                        }
                                        return null;
                                      },
                                      decoration: inputDecoration(context, label: language.amount),
                                    ),
                                    SizedBox(height: 16),
                                    Wrap(
                                      runSpacing: 8,
                                      spacing: 8,
                                      children: appStore.walletPresetTopUpAmount.split('|').map((e) {
                                        return inkWellWidget(
                                          onTap: () {
                                            currentIndex = appStore.walletPresetTopUpAmount.split('|').indexOf(e);
                                            if (appStore.minAmountToAdd != null && num.parse(e) < appStore.minAmountToAdd!) {
                                              // addMoneyController.text = e;
                                              // addMoneyController.selection = TextSelection.fromPosition(TextPosition(offset: appStore.minAmountToAdd.toString().length));
                                              toast("${language.minimum}  ${appStore.minAmountToAdd} ${language.required}");
                                              currentIndex = -1;
                                            } else if (appStore.maxAmountToAdd != null && num.parse(e) > appStore.maxAmountToAdd!) {
                                              // addMoneyController.text = e;
                                              // addMoneyController.selection = TextSelection.fromPosition(TextPosition(offset: e.length));
                                              toast("${language.maximum} ${appStore.maxAmountToAdd} ${language.required}");
                                              currentIndex = -1;
                                            } else {
                                              addMoneyController.text = e;
                                              addMoneyController.selection = TextSelection.fromPosition(TextPosition(offset: e.length));
                                            }

                                            setState(() {});
                                          },
                                          child: Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: currentIndex == appStore.walletPresetTopUpAmount.split('|').indexOf(e) ? primaryColor : Colors.white,
                                                border: Border.all(color: currentIndex == appStore.walletPresetTopUpAmount.split('|').indexOf(e) ? primaryColor : Colors.grey),
                                                borderRadius: BorderRadius.circular(defaultRadius),
                                              ),
                                              child: printAmountWidget(amount: e, color: currentIndex == appStore.walletPresetTopUpAmount.split('|').indexOf(e) ? Colors.white : primaryColor)),
                                        );
                                      }).toList(),
                                    ),
                                    SizedBox(height: 16),
                                    AppButtonWidget(
                                      text: language.addMoney,
                                      textStyle: boldTextStyle(color: Colors.white),
                                      width: MediaQuery.of(context).size.width,
                                      color: primaryColor,
                                      onTap: () {
                                        if (addMoneyController.text.isNotEmpty) {
                                          if (formKey.currentState!.validate() && addMoneyController.text.isNotEmpty) {
                                            Navigator.pop(context);
                                            launchScreen(context, PaymentScreen(amount: num.parse(addMoneyController.text)), pageRouteAnimation: PageRouteAnimation.SlideBottomTop).then((value) {
                                              getWalletData();
                                              setState(() {});
                                            });

                                            addMoneyController.clear();
                                            currentIndex = -1;
                                          } else {
                                            // toast(language.pleaseSelectAmount);
                                            if (appStore.minAmountToAdd != null && num.parse(addMoneyController.text) < appStore.minAmountToAdd!) {
                                              // addMoneyController.text = appStore.minAmountToAdd.toString();
                                              toast("${language.minimum} ${appStore.minAmountToAdd} ${language.required}");
                                            } else if (appStore.maxAmountToAdd != null && num.parse(addMoneyController.text) > appStore.maxAmountToAdd!) {
                                              // addMoneyController.text = appStore.maxAmountToAdd.toString();
                                              toast("${language.maximum} ${appStore.maxAmountToAdd} ${language.required}");
                                            }
                                          }
                                        } else {
                                          toast(language.pleaseSelectAmount);
                                        }
                                      },
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
  }

  getWalletData() async {
    await getWalletList(pageData: currentPage).then((value) {
      appStore.setLoading(false);

      currentPage = value.pagination!.currentPage!;
      totalPage = value.pagination!.totalPages!;
      if (value.walletBalance != null) totalAmount = value.walletBalance!.totalAmount!;
      if (currentPage == 1) {
        walletData.clear();
      }
      walletData.addAll(value.data ?? []);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  getBankDetail() async {
    await getUserDetail(userId: sharedPref.getInt(USER_ID)).then((value) {
      userBankAccount = value.data!.userBankAccount;
      setState(() {});
    }).then((value) {
      log(value);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final canWithdraw = totalAmount > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(language.wallet, style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: Observer(builder: (context) {
        return Stack(
          children: [
            SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  balanceCard(),
                  bankTransferCard(),
                  Text(language.recentTransactions, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DropColors.text(context))),
                  ..._transactions(),
                  if (!appStore.isLoading && walletData.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No transactions yet. Your top-ups, earnings and commission will show here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: DropColors.mutedText(context)))),
                    ),
                ],
              ),
            ),
            Visibility(visible: appStore.isLoading, child: loaderWidget()),
          ],
        );
      }),
      bottomNavigationBar: canWithdraw
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropActionButton(
                  label: language.withDraw,
                  onPressed: () {
                    if (userBankAccount != null && userBankAccount!.accountNumber.validate().isNotEmpty) {
                      launchScreen(context, WithDrawScreen(bankInfo: userBankAccount!, onTap: () => init()));
                    } else {
                      toast(language.bankInfoNotFound);
                      getBankDetail();
                    }
                  },
                ),
              ),
            )
          : null,
    );
  }
}
