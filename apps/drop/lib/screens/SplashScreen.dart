import '../manage_imports.dart';
import '../drop/design/drop_design.dart';
import '../drop/screens/drop_onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkNotifyPermission();
    getAppSettingsData();
  }

  void init() async {
    List<ConnectivityResult> b = await Connectivity().checkConnectivity();
    if (b.contains(ConnectivityResult.none)) {
      return toast(language.yourInternetIsNotWorking);
    }
    await Future.delayed(Duration(seconds: 1));
    if (sharedPref.getBool(IS_FIRST_TIME) ?? true) {
      await Geolocator.requestPermission().then((value) async {
        launchScreen(context, const DropOnboardingScreen(),
            pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
        Geolocator.getCurrentPosition().then((value) {
          sharedPref.setDouble(LATITUDE, value.latitude);
          sharedPref.setDouble(LONGITUDE, value.longitude);
        });
      }).catchError((e) {
        launchScreen(context, const DropOnboardingScreen(),
            pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      });
    } else {
      if (!appStore.isLoggedIn) {
        launchScreen(context, SignInScreen(),
            pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      } else {
        if (sharedPref.getString(CONTACT_NUMBER).validate().isEmptyOrNull) {
          launchScreen(context, EditProfileScreen(isGoogle: true),
              isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        } else {
          getUserDetail(userId: sharedPref.getInt(USER_ID)).then((value) {
            appStore.setUserEmail(value.data!.email.validate());
            appStore.setUserName(value.data!.username.validate());
            appStore.setFirstName(value.data!.firstName.validate());
            appStore.setUserProfile(value.data!.profileImage.validate());
            appStore.setReferralCode(value.data!.referralCode.validate());

            sharedPref.setString(USER_EMAIL, value.data!.email.validate());
            sharedPref.setString(FIRST_NAME, value.data!.firstName.validate());
            sharedPref.setString(LAST_NAME, value.data!.lastName.validate());
            sharedPref.setString(
                USER_PROFILE_PHOTO, value.data!.profileImage.validate());

            appStore.setLoading(false);
            setState(() {});
          }).catchError((error) {
            log(error.toString());
            appStore.setLoading(false);
          });
          if (await checkPermission())
            await Geolocator.requestPermission().then((value) async {
              await Geolocator.getCurrentPosition().then((value) {
                sharedPref.setDouble(LATITUDE, value.latitude);
                sharedPref.setDouble(LONGITUDE, value.longitude);
                launchScreen(context, DashBoardScreen(),
                    pageRouteAnimation: PageRouteAnimation.Slide,
                    isNewTask: true);
              });
            }).catchError((e) {
              launchScreen(context, DashBoardScreen(),
                  pageRouteAnimation: PageRouteAnimation.Slide,
                  isNewTask: true);
            });
        }
      }
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DropColors.background(context),
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          builder: (BuildContext context, double t, Widget? child) => Opacity(opacity: t, child: child),
          child: const DropLogo(width: 96, markOnly: true),
        ),
      ),
    );
  }


  void _checkNotifyPermission() async {
    String versionNo =
        sharedPref.getString(CURRENT_LAN_VERSION) ?? LanguageVersion;
    await getLanguageList(versionNo).then((value) {
      appStore.setLoading(false);
      app_update_check = value.rider_version;
      if (value.status == true) {
        setValue(CURRENT_LAN_VERSION, value.currentVersionNo.toString());
        if (value.data!.length > 0) {
          defaultServerLanguageData = value.data;
          performLanguageOperation(defaultServerLanguageData);
          setValue(LanguageJsonDataRes, value.toJson());
          bool isSetLanguage =
              sharedPref.getBool(IS_SELECTED_LANGUAGE_CHANGE) ?? false;
          if (!isSetLanguage) {
            for (int i = 0; i < value.data!.length; i++) {
              if (value.data![i].isDefaultLanguage == 1) {
                setValue(SELECTED_LANGUAGE_CODE, value.data![i].languageCode);
                setValue(
                    SELECTED_LANGUAGE_COUNTRY_CODE, value.data![i].countryCode);
                appStore.setLanguage(value.data![i].languageCode!,
                    context: context);
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
          ServerLanguageResponse languageSettings =
              ServerLanguageResponse.fromJson(json.decode(getJsonData.trim()));
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
    init();
    // if (await Permission.notification.isGranted) {
    //   init();
    // } else {
    //   await Permission.notification.request();
    //   init();
    // }
  }
}
