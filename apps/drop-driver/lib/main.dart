import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_driver/screens/SplashScreen.dart';
import 'package:taxi_driver/store/AppStore.dart';
import 'package:taxi_driver/utils/Colors.dart';
import 'package:taxi_driver/utils/Common.dart';
import 'package:taxi_driver/utils/Constants.dart';
import 'package:taxi_driver/utils/Extensions/dataTypeExtensions.dart';

import 'AppTheme.dart';
import 'Services/ChatMessagesService.dart';
import 'Services/NotificationService.dart';
import 'Services/UserServices.dart';
import 'languageConfiguration/AppLocalizations.dart';
import 'languageConfiguration/BaseLanguage.dart';
import 'languageConfiguration/LanguageDataConstant.dart';
import 'languageConfiguration/LanguageDefaultJson.dart';
import 'languageConfiguration/ServerLanguageResponse.dart';
import 'model/FileModel.dart';
import 'screens/NoInternetScreen.dart';
import 'utils/Extensions/app_common.dart';

LanguageJsonData? selectedServerLanguageData;
List<LanguageJsonData>? defaultServerLanguageData = [];

AppStore appStore = AppStore();
late SharedPreferences sharedPref;
Color textPrimaryColorGlobal = textPrimaryColor;
Color textSecondaryColorGlobal = textSecondaryColor;
Color defaultLoaderBgColorGlobal = Colors.white;

late BaseLanguage language;
final GlobalKey netScreenKey = GlobalKey();
final GlobalKey locationScreenKey = GlobalKey();

late List<FileModel> fileList = [];
bool mIsEnterKey = false;
int REQUEST_TIME_VAL = 60;
ChatMessageService chatMessageService = ChatMessageService();
NotificationService notificationService = NotificationService();
UserService userService = UserService();

final navigatorKey = GlobalKey<NavigatorState>();

get getContext => navigatorKey.currentState?.overlay?.context;
late LocationPermission locationPermissionHandle;

var app_update_check = null;
var marker_size_height = 120;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isIOS) {
    await Firebase.initializeApp().then((value) {});
  } else {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(apiKey: apiKeyFirebase, authDomain: authDomain, projectId: projectId, storageBucket: storageBucket, messagingSenderId: messagingSenderId, appId: appIdAndroid),
      ).then((value) {});
    } catch (e) {
      await Firebase.initializeApp();
    }
  }
  FlutterError.onError = (
    errorDetails,
  ) {
    FirebaseCrashlytics.instance.recordError(errorDetails.exception, errorDetails.stack, fatal: true);
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordFlutterError(FlutterErrorDetails(exception: error, stack: stack));
    FirebaseCrashlytics.instance.recordError(error, stack);
    return true;
  };
  sharedPref = await SharedPreferences.getInstance();
  appStore.setLanguage(sharedPref.getString(SELECTED_LANGUAGE_CODE) ?? defaultLanguageCode);
  await appStore.setLoggedIn(sharedPref.getBool(IS_LOGGED_IN) ?? false, isInitializing: true);
  await appStore.setUserId(sharedPref.getInt(USER_ID) ?? 0, isInitializing: true);
  await appStore.setUserEmail(sharedPref.getString(USER_EMAIL).validate(), isInitialization: true);
  await appStore.setUserProfile(sharedPref.getString(USER_PROFILE_PHOTO).validate(), isInitialization: true);
  initJsonFile();
  await oneSignalSettings();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await mightyCoreInit();
  runApp(MyApp());
}

Future<void> mightyCoreInit() async {
  MightyCore().init(
    baseUrl: mBaseUrl,
    sharedPref: sharedPref,
    navigatorKey: navigatorKey,
  );
  String? oldToken = sharedPref.getString(TOKEN);
  if (oldToken != null) {
    MightyCore().configure(authToken: oldToken);
  }
}


class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<ConnectivityResult>> connectivitySubscription;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((e) {
      if (e.contains(ConnectivityResult.none)) {
        log('not connected');
        launchScreen(navigatorKey.currentState!.overlay!.context, NoInternetScreen());
      } else {
        if (netScreenKey.currentContext != null) {
          if (Navigator.canPop(navigatorKey.currentState!.overlay!.context)) {
            Navigator.pop(navigatorKey.currentState!.overlay!.context);
          }
        }
        // toast('Internet is connected.');
        log('connected');
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
    connectivitySubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: mAppName,
        theme: AppTheme.lightTheme,
        // builder: (context, child) {
        //   return ScrollConfiguration(behavior: MyBehavior(), child: child!);
        // },
        builder: (context, child) {
          return SafeArea(top: false, child: ScrollConfiguration(behavior: MyBehavior(), child: child!));
        },
        home: SplashScreen(),
        supportedLocales: getSupportedLocales(),
        locale: Locale(appStore.selectedLanguage.validate(value: defaultLanguageCode).split('_').first),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          CountryLocalizations.delegate,
          AppLocalizations(),
        ],
        // locale: Locale(appStore.selectedLanguage.validate(value: defaultLanguageCode)),
        // localizationsDelegates: [
        //   AppLocalizations(),
        //   CountryLocalizations.delegate,
        //   GlobalMaterialLocalizations.delegate,
        //   GlobalWidgetsLocalizations.delegate,
        //   GlobalCupertinoLocalizations.delegate,
        // ],
        // localeResolutionCallback: (locale, supportedLocales) => locale,
      );
    });
  }
}
