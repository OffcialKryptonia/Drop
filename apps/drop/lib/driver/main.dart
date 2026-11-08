
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drop/driver/screens/SplashScreen.dart';
import 'package:drop/driver/store/AppStore.dart';
import 'package:drop/driver/utils/Colors.dart';
import 'package:drop/driver/utils/Common.dart';
import 'package:drop/driver/utils/Constants.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

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

bool _driverModuleReady = false;

/// Prepares the driver module. Called by the unified app (never runApp here):
/// Firebase, SharedPreferences, MightyCore and crash hooks are already set up
/// by the rider-side main(), so this only fills the driver module's own globals.
Future<void> initDriverModule() async {
  if (_driverModuleReady) return;
  sharedPref = await SharedPreferences.getInstance();
  appStore.setLanguage(sharedPref.getString(SELECTED_LANGUAGE_CODE) ?? defaultLanguageCode);
  await appStore.setLoggedIn(sharedPref.getBool(IS_LOGGED_IN) ?? false, isInitializing: true);
  await appStore.setUserId(sharedPref.getInt(USER_ID) ?? 0, isInitializing: true);
  await appStore.setUserEmail(sharedPref.getString(USER_EMAIL).validate(), isInitialization: true);
  await appStore.setUserProfile(sharedPref.getString(USER_PROFILE_PHOTO).validate(), isInitialization: true);
  initJsonFile();
  await oneSignalSettings();
  await mightyCoreInit();
  _driverModuleReady = true;
}

Future<void> mightyCoreInit() async {
  // MightyCore is a process-wide singleton already initialised by the rider side.
  String? oldToken = sharedPref.getString(TOKEN);
  if (oldToken != null) {
    MightyCore().configure(authToken: oldToken);
  }
}

/// Driver mode root. A nested MaterialApp keeps the driver theme, localisation
/// and its own navigator stack, so none of the driver screens needed rewriting.
class DriverShell extends StatelessWidget {
  const DriverShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: mAppName,
        theme: AppTheme.lightTheme,
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
      );
    });
  }
}
