import 'package:drop/service/DriverApplicationApi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:drop/driver/screens/DriverWithdrawScreen.dart';
import 'package:drop/drop/screens/drop_help_screen.dart';
import 'package:drop/driver/screens/ReviewsListScreen.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

import '../main.dart';
import '../network/RestApis.dart';
import '../screens/BankInfoScreen.dart';
import '../screens/DocumentsScreen.dart';
import '../screens/EarningScreen.dart';
import '../screens/EditProfileScreen.dart';
import '../screens/EmergencyContactScreen.dart';
import '../screens/FAQ_Screen.dart';
import '../screens/RewardListScreen.dart';
import '../screens/RidesListScreen.dart';
import '../screens/ScheduleRideListScreen.dart';
import '../screens/SettingScreen.dart';
import '../screens/VehicleScreen.dart';
import '../screens/WalletScreen.dart';
import '../screens/refer_earn_screen.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Images.dart';
import 'DrawerWidget.dart';
import 'package:drop/components/ModeSwitchTile.dart';

class DrawerComponent extends StatefulWidget {
  final Function? onCall;

  DrawerComponent({this.onCall});

  @override
  State<DrawerComponent> createState() => _DrawerComponentState();
}

class _DrawerComponentState extends State<DrawerComponent> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 35),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Observer(builder: (context) {
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: radius(),
                      child: commonCachedNetworkImage(appStore.userProfile.validate(), height: 70, width: 70, fit: BoxFit.cover),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sharedPref.getString(FIRST_NAME).validate().capitalizeFirstLetter() + " " + sharedPref.getString(LAST_NAME).validate().capitalizeFirstLetter(), style: boldTextStyle()),
                          SizedBox(height: 4),
                          Text(appStore.userEmail, style: secondaryTextStyle()),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
            Divider(thickness: 1, height: 40),
            ModeSwitchTile(target: 'rider'),
            DrawerWidget(
                title: language.profile,
                iconData: ic_my_profile,
                icon: FontAwesome.user_o,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(
                      context,
                      EditProfileScreen(
                        isGoogle: false,
                      ),
                      pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.schedule,
                iconData: ic_my_rides,
                icon: Ionicons.car_outline,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, ScheduleRideListScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.rides,
                iconData: ic_my_rides,
                icon: Ionicons.car_outline,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, RidesListScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: 'Reviews',
                iconData: ic_my_rides,
                icon: Ionicons.car_outline,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, ReviewsListScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.updateVehicleInfo,
                iconData: ic_vehical_detail,
                icon: Ionicons.car_outline,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, VehicleScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.wallet,
                iconData: ic_my_wallet,
                icon: Ionicons.ios_wallet_outline,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, WalletScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.emergencyContacts,
                iconData: ic_emergency,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, EmergencyContactScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.earnings,
                iconData: ic_wallet,
                icon: Ionicons.ios_wallet_outline,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, EarningScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: 'Help & complaints',
                iconData: payout_icon,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, DropHelpScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: 'Withdraw & payouts',
                iconData: payout_icon,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, DriverWithdrawScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.documents,
                icon: Ionicons.document_outline,
                iconData: ic_verify_document,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, DocumentsScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.bankInfo,
                iconData: ic_update_bank_info,
                icon: MaterialCommunityIcons.bank_outline,
                onTap: () {
                  Navigator.pop(context);
                  launchScreen(context, BankInfoScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                paddingApply: true,
                title: language.refer_and_earn,
                iconData: ic_earn,
                onTap: () {
                  launchScreen(context, ReferEarnScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                paddingApply: true,
                title: language.earned_reward,
                iconData: ic_reward,
                onTap: () {
                  launchScreen(context, RewardListScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.lblfaq,
                paddingApply: true,
                iconData: ic_faq,
                onTap: () {
                  launchScreen(context, FAQScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.settings,
                iconData: ic_setting,
                onTap: () {
                  launchScreen(context, SettingScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                }),
            DrawerWidget(
                title: language.logOut,
                iconData: ic_logout,
                onTap: () async {
                  await showConfirmDialogCustom(context, primaryColor: primaryColor, dialogType: DialogType.CONFIRMATION, title: language.areYouSureYouWantToLogoutThisApp, positiveText: language.yes, negativeText: language.no, onAccept: (v) async {
                    // Go offline first (best effort), then sign out whatever the network says.
                    try {
                      if (widget.onCall != null) {
                        await widget.onCall!();
                      } else {
                        await DriverApplicationApi.setOnline(false).timeout(Duration(seconds: 4));
                      }
                    } catch (_) {}
                    await logout();
                  });
                }),
          ],
        ),
      ),
    );
  }
}
