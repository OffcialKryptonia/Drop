import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'manage_imports.dart';

LanguageJsonData? selectedServerLanguageData;
List<LanguageJsonData>? defaultServerLanguageData = [];

AppStore appStore = AppStore();
late SharedPreferences sharedPref;
Color textPrimaryColorGlobal = textPrimaryColor;
Color textSecondaryColorGlobal = textSecondaryColor;
Color defaultLoaderBgColorGlobal = Colors.white;
LatLng polylineSource = LatLng(0.00, 0.00);
LatLng polylineDestination = LatLng(0.00, 0.00);
late BaseLanguage language;
bool mIsEnterKey = false;
final GlobalKey netScreenKey = GlobalKey();
final GlobalKey locationScreenKey = GlobalKey();
ChatMessageService chatMessageService = ChatMessageService();
NotificationService notificationService = NotificationService();
UserService userService = UserService();
late Position currentPosition;
final navigatorKey = GlobalKey<NavigatorState>();

get getContext => navigatorKey.currentState?.overlay?.context;
var app_update_check = null;
LatLng? sourceLocation;
late BitmapDescriptor riderIcon;
String sourceLocationTitle = '';

// const int marker_size_width = 150;
const int marker_size_height = 120;
bool isPopupOpen = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedPref = await SharedPreferences.getInstance();

  if (Platform.isIOS) {
    await Firebase.initializeApp();
  } else {
    try {
      await Firebase.initializeApp(
          options: FirebaseOptions(
        apiKey: apiKeyFirebase,
        appId: appIdAndroid,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
      ));
    } catch (e) {
      await Firebase.initializeApp();
    }
  }
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  appStore.setLanguage(sharedPref.getString(SELECTED_LANGUAGE_CODE) ?? defaultLanguageCode);
  await appStore.setLoggedIn(sharedPref.getBool(IS_LOGGED_IN) ?? false, isInitializing: true);
  await appStore.setUserEmail(sharedPref.getString(USER_EMAIL) ?? '', isInitialization: true);
  await appStore.setUserProfile(sharedPref.getString(USER_PROFILE_PHOTO) ?? '');
  try {
    initJsonFile();
  } catch (e) {}
  try {
    await oneSignalSettings();
  } catch (e) {}
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  tz.initializeTimeZones();
  await mightyCoreInit();
  runApp(MyApp());
}

Future<void> mightyCoreInit() async {
  MightyCore().init(
    baseUrl: mBaseUrl,
    sharedPref: sharedPref,
    navigatorKey: navigatorKey,
  );
}

Future<void> updatePlayerId() async {
  Map req = {
    "player_id": sharedPref.getString(PLAYER_ID),
  };
  updateStatus(req).then((value) {
    //
  }).catchError((error) {
    //
  });
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

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
    connectivitySubscription.cancel();
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
        log('connected');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: mAppName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: appStore.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) {
          return SafeArea(top: false, child: ScrollConfiguration(behavior: MyBehavior(), child: child!));
        },
        home: SplashScreen(),
        supportedLocales: getSupportedLocales(),
        locale: Locale(appStore.selectedLanguage.validate(value: defaultLanguageCode)),
        localizationsDelegates: [
          AppLocalizations(),
          CountryLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supportedLocales) => locale,
      );
    });
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
