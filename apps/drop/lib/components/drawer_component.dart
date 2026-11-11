import 'package:drop/screens/ReviewsScreen.dart';

import '../manage_imports.dart';
import 'ModeSwitchTile.dart';

class DrawerComponent extends StatefulWidget {
  final Function(String)? onClose;

  const DrawerComponent({Key? key, this.onClose}) : super(key: key);

  @override
  State<DrawerComponent> createState() => _DrawerComponentState();
}

class _DrawerComponentState extends State<DrawerComponent> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          SingleChildScrollView(
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
                          child: commonCachedNetworkImage(appStore.userProfile.validate().validate(), height: 70, width: 70, fit: BoxFit.cover),
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
                ModeSwitchTile(target: 'driver'),
                DrawerWidget(
                  title: language.profile,
                  iconData: ic_my_profile,
                  onTap: () {
                    Navigator.pop(context);
                    launchScreen(context, EditProfileScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                  },
                ),
                // if (appStore.isScheduleRide == "1")
                DrawerWidget(
                  title: language.schedule_list_title,
                  iconData: ic_schedule,
                  paddingApply: true,
                  onTap: () {
                    Navigator.pop(context);
                    launchScreen(context, ScheduleRideListScreen());
                  },
                ),
                DrawerWidget(
                    title: language.rides,
                    iconData: ic_my_rides,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, RideListScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: 'Reviews',
                    iconData: ic_my_rides,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, ReviewsScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    paddingApply: true,
                    title: language.estimate,
                    iconData: ic_estimate,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onClose?.call("openBottom");
                    }),
                DrawerWidget(
                    title: language.wallet,
                    iconData: ic_my_wallet,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, WalletScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.emergencyContacts,
                    iconData: ic_emergency_contact,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EmergencyContactScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    paddingApply: true,
                    title: language.refer_and_earn,
                    iconData: ic_earn,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, ReferEarnScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    paddingApply: true,
                    title: 'Drop Coin History',
                    iconData: ic_earn,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, CoinWalletListScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    paddingApply: true,
                    title: language.earned_reward,
                    iconData: ic_reward,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, RewardListScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    paddingApply: true,
                    title: language.lblfaq,
                    iconData: ic_faq,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, FAQScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.settings,
                    iconData: ic_setting,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, SettingScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.logOut,
                    iconData: ic_logout,
                    onTap: () async {
                      await showConfirmDialogCustom(context, primaryColor: primaryColor, dialogType: DialogType.CONFIRMATION, title: language.areYouSureYouWantToLogoutThisApp, positiveText: language.yes, negativeText: language.no, onAccept: (v) async {
                        await appStore.setLoggedIn(true);
                        await Future.delayed(Duration(milliseconds: 500));
                        await logout();
                      });
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
