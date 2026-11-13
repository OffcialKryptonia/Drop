import 'package:drop/service/DriverApplicationApi.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:drop/driver/screens/RefferalHistoryScreen.dart';
import 'package:drop/driver/utils/Colors.dart';
import 'package:drop/driver/utils/Constants.dart';
import 'package:drop/driver/utils/Extensions/ResponsiveWidget.dart';
import 'package:drop/driver/utils/Extensions/context_extensions.dart';
import 'package:drop/driver/utils/Extensions/int_extensions.dart';

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
  String code = '';
  bool loadingCode = true;

  @override
  void initState() {
    super.initState();
    code = (appStore.referralCode ?? '').trim();
    if (code == 'null') code = '';
    _loadCode();
  }

  /// The code comes from the server every time: switching from rider mode never goes through driver sign-in.
  Future<void> _loadCode() async {
    try {
      final r = await DriverApplicationApi.driverProfile();
      final c = (r['referral_code'] ?? '').toString().trim();
      if (c.isNotEmpty) {
        code = c;
        appStore.setReferralCode(c);
      }
    } catch (_) {}
    if (mounted) setState(() => loadingCode = false);
  }

  bool get _hasReward => (num.tryParse(sharedPref.getString("reference_amount") ?? '0') ?? 0) > 0;

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
              if (_hasReward) ...[
                Text("${language.lblReferTitle}: ${sharedPref.getString("reference_type") == "fixed" ? "${appStore.currencyCode} ${sharedPref.getString("reference_amount")}" : "${sharedPref.getString("reference_amount")}%"}", style: boldTextStyle(), textAlign: TextAlign.center),
                10.height,
                Text("${language.lblReferSubtitle}: ${appStore.currencyCode} ${sharedPref.getString("maxEarningPerMonth")} monthly", style: secondaryTextStyle(), textAlign: TextAlign.center).center().paddingSymmetric(0, 20),
              ] else
                Text('Share your code with friends so they join DROP.', style: secondaryTextStyle(), textAlign: TextAlign.center).center().paddingSymmetric(0, 20),
              30.height,
              DottedBorder(
                  dashPattern: [6, 3, 2, 3],
                  color: primaryColor,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(code.isNotEmpty ? code : (loadingCode ? '...' : 'No code yet'), style: boldTextStyle(size: 20)).paddingAll(8), Icon(Icons.copy, size: 18).paddingAll(8)],
                  )).onTap(() {
                if (code.isEmpty) return;
                Clipboard.setData(ClipboardData(text: code)).then((_) {
                  toast("$code Copied to clipboard");
                });
              }),
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
                if (code.isEmpty) return;
                SharePlus.instance.share(ShareParams(text: 'Hey! Use my referral code $code and join $mAppName to support me!'));
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
