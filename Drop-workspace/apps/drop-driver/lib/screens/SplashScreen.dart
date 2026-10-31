import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:taxi_driver/screens/DashboardScreen.dart';
import 'package:taxi_driver/screens/SignInScreen.dart';
import 'package:taxi_driver/utils/Extensions/dataTypeExtensions.dart';

import '../languageConfiguration/LanguageDataConstant.dart';
import '../languageConfiguration/ServerLanguageResponse.dart';
import '../main.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Images.dart';
import 'DocumentsScreen.dart';
import 'EditProfileScreen.dart';
import 'WalkThroughScreen.dart';

class SplashScreen extends StatefulWidget {
  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkNotifyPermission();
    getSettings();
  }

  void init() async {
    List<ConnectivityResult> b = await Connectivity().checkConnectivity();
    if (b.contains(ConnectivityResult.none)) {
      return toast(language.yourInternetIsNotWorking);
    }
    await driverDetail();

    await Future.delayed(Duration(seconds: 1));
    if (sharedPref.getBool(IS_FIRST_TIME) ?? true) {
      await Geolocator.requestPermission().then((value) async {
        launchScreen(context, WalkThroughScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
        Geolocator.getCurrentPosition().then((value) {
          sharedPref.setDouble(LATITUDE, value.latitude);
          sharedPref.setDouble(LONGITUDE, value.longitude);
        });
      }).catchError((e) {
        launchScreen(context, WalkThroughScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      });
    } else {
      if (sharedPref.getString(CONTACT_NUMBER).validate().isEmptyOrNull && appStore.isLoggedIn) {
        launchScreen(context, EditProfileScreen(isGoogle: true), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
      } else if (sharedPref.getString(UID).validate().isEmptyOrNull && appStore.isLoggedIn) {
        updateProfileUid().then((value) {
          if (sharedPref.getInt(IS_Verified_Driver) == 1) {
            launchScreen(context, DashboardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          } else {
            launchScreen(context, DocumentsScreen(isShow: true), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          }
        });
      } else if (sharedPref.getInt(IS_Verified_Driver) == 0 && appStore.isLoggedIn) {
        launchScreen(context, DocumentsScreen(isShow: true), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      } else if (sharedPref.getInt(IS_Verified_Driver) == 1 && appStore.isLoggedIn) {
        launchScreen(context, DashboardScreen(), pageRouteAnimation: PageRouteAnimation.SlideBottomTop, isNewTask: true);
      } else {
        launchScreen(context, SignInScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      }
    }
  }

  Future<void> driverDetail() async {
    if (appStore.isLoggedIn) {
      await getUserDetail(userId: sharedPref.getInt(USER_ID)).then((value) async {
        await sharedPref.setInt(IS_ONLINE, value.data!.isOnline!);
        if (value.data!.status == REJECT || value.data!.status == BANNED) {
          toast('${language.yourAccountIs} ${value.data!.status}. ${language.pleaseContactSystemAdministrator}');
          logout();
        }
        appStore.setUserEmail(value.data!.email.validate());
        appStore.setUserName(value.data!.username.validate());
        appStore.setFirstName(value.data!.firstName.validate());
        appStore.setUserProfile(value.data!.profileImage.validate());
        appStore.setReferralCode(value.data!.referralCode.validate());

        sharedPref.setString(USER_EMAIL, value.data!.email.validate());
        sharedPref.setString(FIRST_NAME, value.data!.firstName.validate());
        sharedPref.setString(LAST_NAME, value.data!.lastName.validate());
      }).catchError((error) {});
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 0,
        // backgroundColor: Colors.transparent,
        // systemOverlayStyle: SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarColor: Colors.black, statusBarBrightness: Brightness.dark),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(ic_logo_white, fit: BoxFit.contain, height: 150, width: 150),
            SizedBox(height: 16),
            Text(mAppName, style: boldTextStyle(color: Colors.white, size: 22)),
          ],
        ),
      ),
    );
  }

  void _checkNotifyPermission() async {
    String versionNo = sharedPref.getString(CURRENT_LAN_VERSION) ?? LanguageVersion;

    await getLanguageList(versionNo).then((value) async {
      appStore.setLoading(false);
      app_update_check = value.driver_version;
      if (value.status == true) {
        setValue(CURRENT_LAN_VERSION, value.currentVersionNo.toString());
        if (value.data!.length > 0) {
          defaultServerLanguageData = value.data;
          performLanguageOperation(defaultServerLanguageData);
          setValue(LanguageJsonDataRes, value.toJson());
          bool isSetLanguage = sharedPref.getBool(IS_SELECTED_LANGUAGE_CHANGE) ?? false;
          if (!isSetLanguage) {
            for (int i = 0; i < value.data!.length; i++) {
              if (value.data![i].isDefaultLanguage == 1) {
                setValue(SELECTED_LANGUAGE_CODE, value.data![i].languageCode);
                setValue(SELECTED_LANGUAGE_COUNTRY_CODE, value.data![i].countryCode);
                appStore.setLanguage(value.data![i].languageCode!, context: context);
                break;
              }
            }
          }
        } else {
          defaultServerLanguageData = [];
          selectedServerLanguageData = null;
          setValue(LanguageJsonDataRes, "");
        }
      } else {
        String getJsonData = sharedPref.getString(LanguageJsonDataRes) ?? '';
        if (getJsonData.isNotEmpty) {
          ServerLanguageResponse languageSettings = ServerLanguageResponse.fromJson(json.decode(getJsonData.trim()));
          if (languageSettings.data!.length > 0) {
            defaultServerLanguageData = languageSettings.data;
            performLanguageOperation(defaultServerLanguageData);
          }
        }
      }
    }).catchError((error) {
      appStore.setLoading(false);
      log(error);
    });
    if (await Permission.notification.isGranted) {
      init();
    } else {
      await Permission.notification.request();
      init();
    }
  }
}
