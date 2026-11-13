import 'package:flutter/material.dart';

import '../components/EarningReportWidget.dart';
import '../components/EarningTodayWidget.dart';
import '../components/EarningWeekWidget.dart';
import '../main.dart';
import '../model/EarningListModelWeek.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_common.dart';

class EarningScreen extends StatefulWidget {
  @override
  EarningScreenState createState() => EarningScreenState();
}

class EarningScreenState extends State<EarningScreen> {
  EarningListModelWeek? earningListModelWeek;
  List<WeekReport> weekReport = [];

  num totalRideCount = 0;
  num totalCashRide = 0;
  num totalWalletRide = 0;
  num totalCardRide = 0;
  num totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() {}

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(language.earnings,
              style: boldTextStyle(color: appTextPrimaryColorWhite)),
        ),
        body: Column(
          children: [
            Container(
              height: 40,
              margin: EdgeInsets.only(right: 16, left: 16, top: 16),
              decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: dividerColor),
                  borderRadius: radius(defaultRadius + 2)),
              child: TabBar(
                dividerHeight: 0,
                padding: EdgeInsets.all(2),
                indicator:
                    BoxDecoration(borderRadius: radius(), color: primaryColor),
                labelColor: Colors.white,
                unselectedLabelColor: primaryColor,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: boldTextStyle(color: Colors.white, size: 14),
                tabs: [
                  Text(language.today),
                  Text(language.weekly),
                  Text(language.report),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  EarningTodayWidget(),
                  EarningWeekWidget(),
                  EarningReportWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
