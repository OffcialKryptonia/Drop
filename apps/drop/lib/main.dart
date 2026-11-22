import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'manage_imports.dart';
import 'drop/widgets/drop_connectivity_banner.dart';
import 'package:drop/driver/main.dart' as drv;
import 'service/ModeController.dart';

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

Future<void> _initFirebase() async {
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
}

/// Only what is local and needed to draw the first screen happens here. Nothing in this function talks to the
/// network: push set-up, language updates, settings and the session check all start after the first frame (see [BootTasks]).
void main() async {
  BootTimings.mark('main');
  WidgetsFlutterBinding.ensureInitialized();
  // Independent local work runs side by side instead of one after another.
  final prefsReady = SharedPreferences.getInstance();
  final firebaseReady = _initFirebase().catchError((_) {});
  final keywordsReady = Future<void>.sync(() => initJsonFile()).catchError((_) {});
  sharedPref = await prefsReady;
  BootTimings.mark('prefs');

  appStore.setLanguage(sharedPref.getString(SELECTED_LANGUAGE_CODE) ?? defaultLanguageCode);
  await appStore.setLoggedIn(sharedPref.getBool(IS_LOGGED_IN) ?? false, isInitializing: true);
  ModeController.onSignedOut = () => appStore.setLoggedIn(false);
  await ModeController.restore(sharedPref);
  await appStore.setUserEmail(sharedPref.getString(USER_EMAIL) ?? '', isInitialization: true);
  await appStore.setUserProfile(sharedPref.getString(USER_PROFILE_PHOTO) ?? '');
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await mightyCoreInit();
  await Future.wait([firebaseReady, keywordsReady]);
  BootTimings.mark('ready');
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
  @override
  void initState() {
    super.initState();
    // After the first frame: connectivity, push, language, settings and the session check. None of it can delay the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BootTimings.mark('first_frame');
      BootTasks.run();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ModeController.mode,
      builder: (context, mode, _) => mode == 'driver' ? _DriverHost() : _riderApp(),
    );
  }

  Widget _riderApp() {
    return Observer(builder: (context) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: mAppName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: appStore.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) {
          return DropConnectivityHost(child: SafeArea(top: false, child: ScrollConfiguration(behavior: MyBehavior(), child: child!)));
        },
        home: bootHome(),
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


/// Driver mode root: prepares the driver module, then shows it.
class _DriverHost extends StatefulWidget {
  @override
  State<_DriverHost> createState() => _DriverHostState();
}

class _DriverHostState extends State<_DriverHost> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    drv.initDriverModule().whenComplete(() {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const ColoredBox(color: Colors.white); // local set-up only: one quick frame, no spinner
    }
    return drv.DriverShell();
  }
}
