import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:taxi_driver/screens/RefferalHistoryScreen.dart';
import 'package:taxi_driver/utils/Colors.dart';
import 'package:taxi_driver/utils/Constants.dart';
import 'package:taxi_driver/utils/Extensions/ResponsiveWidget.dart';
import 'package:taxi_driver/utils/Extensions/context_extensions.dart';
import 'package:taxi_driver/utils/Extensions/int_extensions.dart';

import '../main.dart';
import '../utils/Extensions/app_button.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Images.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          language.refer_and_earn,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
              onPressed: () {
                launchScreen(context, ReferralHistoryScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
              },
              icon: Icon(Icons.history))
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(ic_refer_earn, width: 200),
              10.height,
              Text("${language.lblReferTitle}: ${sharedPref.getString("reference_type") == "fixed" ? "${appStore.currencyCode} ${sharedPref.getString("reference_amount")}" : "${sharedPref.getString("reference_amount")}%"}", style: boldTextStyle(), textAlign: TextAlign.center),
              10.height,
              Text("${language.lblReferSubtitle}: ${appStore.currencyCode} ${sharedPref.getString("maxEarningPerMonth")} monthly", style: secondaryTextStyle(), textAlign: TextAlign.center).center().paddingSymmetric(0, 20),
              30.height,
              DottedBorder(
                  dashPattern: [6, 3, 2, 3],
                  color: primaryColor,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(appStore.referralCode.toString(), style: boldTextStyle(size: 20)).paddingAll(8), Icon(Icons.copy, size: 18).paddingAll(8)],
                  )).onTap(() {
                Clipboard.setData(ClipboardData(text: appStore.referralCode.toString())).then((_) {
                  toast("${appStore.referralCode.toString()} Copied to clipboard");
                });
              }) /*.visible(!appStore.referralCode!.isEmpty)*/,
              30.height,
              Divider(thickness: 1, color: Colors.grey.withValues(alpha: 0.3)),
            ],
          ).paddingAll(20),
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: AppButton(
              width: context.width(),
              color: primaryColor,
              text: language.refer_and_earn,
              textStyle: primaryTextStyle(color: Colors.white),
              onTap: () {
                SharePlus.instance.share(ShareParams(text: 'Hey! Use my referral code ${appStore.referralCode} and join $mAppName to support me!'));
                // Share.share('${language.shareDes1} ${language.appName}, ${language.shareDes2} '
                //     '${appStore.referralCode} ${language.shareDes3} 🚀');
              },
            ),
          ),
        ],
      ),
    );
  }
}
