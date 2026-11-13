import 'package:flutter/material.dart';

import '../main.dart';
import '../network/RestApis.dart';
import '../utils/Extensions/extension.dart';
import '../utils/utils.dart';

class EarningTodayWidget extends StatefulWidget {
  @override
  EarningTodayWidgetState createState() => EarningTodayWidgetState();
}

class EarningTodayWidgetState extends State<EarningTodayWidget> {
  num totalCashRide = 0;
  num totalWalletRide = 0;
  num todayEarnings = 0;
  num todayRideRequest = 0;
  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  /// Own loading flag: the shared one is flipped by the other tabs and could leave this spinner stuck.
  void init() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final value = await earningList(req: {"type": "today"});
      totalCashRide = value.totalCashRide ?? 0;
      totalWalletRide = value.totalWalletRide ?? 0;
      todayEarnings = value.todayEarnings ?? 0;
      todayRideRequest = value.todayRideRequest ?? 0;
    } catch (error) {
      failed = true;
      log(error.toString());
    }
    setState(() => loading = false);
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(top: 16, bottom: 16, right: 16, left: 16),
          child: Column(
            children: [
              earningText(
                  title: language.rides,
                  amount: todayRideRequest,
                  isRides: true),
              SizedBox(height: 16),
              earningText(title: language.cash, amount: totalCashRide),
              SizedBox(height: 16),
              earningText(title: language.wallet, amount: totalWalletRide),
              SizedBox(height: 16),
              Divider(color: primaryColor),
              earningText(
                  title: language.todayEarning,
                  amount: todayEarnings,
                  isTotal: true),
              SizedBox(height: 16),
            ],
          ),
        ),
        if (loading) loaderWidget(),
        if (!loading && failed)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Could not load your earnings.', style: secondaryTextStyle()),
              TextButton(onPressed: init, child: Text('Try again')),
            ]),
          ),
      ],
    );
  }
}
