import 'dart:async';

import 'package:timezone/data/latest.dart' as tz;

import '../drop/screens/drop_onboarding_screen.dart';
import '../manage_imports.dart';
import '../service/DriverApplicationApi.dart' show ApiFailure, DriverApplicationApi;
import '../service/net/connectivity_service.dart';
import '../service/net/drop_cache.dart';

/// Where the app opens, decided from what is saved on the phone. No network, no waiting.
enum BootTarget { onboarding, signIn, completeProfile, home }

/// A saved session is only a *convenience to show the right screen*. It is not permission: every action still
/// carries the token and the server decides. Without a token there is no session, whatever else is saved.
BootTarget decideBootTarget({required bool firstTime, required bool loggedIn, required String token, required String contactNumber}) {
  if (firstTime) return BootTarget.onboarding;
  if (!loggedIn || token.isEmpty) return BootTarget.signIn;
  if (contactNumber.isEmpty) return BootTarget.completeProfile;
  return BootTarget.home;
}

/// The first screen, built synchronously from local data. There is no splash route and no spinner after the
/// native launch screen: the next thing the person sees is the app.
Widget bootHome() {
  switch (decideBootTarget(
    firstTime: sharedPref.getBool(IS_FIRST_TIME) ?? true,
    loggedIn: appStore.isLoggedIn,
    token: sharedPref.getString(TOKEN).validate(),
    contactNumber: sharedPref.getString(CONTACT_NUMBER).validate(),
  )) {
    case BootTarget.onboarding:
      return const DropOnboardingScreen();
    case BootTarget.signIn:
      return SignInScreen();
    case BootTarget.completeProfile:
      return EditProfileScreen(isGoogle: true);
    case BootTarget.home:
      return DashBoardScreen();
  }
}

/// Start-up stopwatch, so real devices can report real numbers (see the PR for how to read them).
class BootTimings {
  BootTimings._();
  static final Stopwatch _watch = Stopwatch()..start();
  static final Map<String, int> marks = {};

  static void mark(String name) {
    marks.putIfAbsent(name, () => _watch.elapsedMilliseconds);
    log('DROP_BOOT $name=${marks[name]}ms');
  }
}

/// Everything that used to hold up the splash screen, now run after the first frame, side by side, each allowed to fail.
class BootTasks {
  BootTasks._();
  static bool _ran = false;

  static void run() {
    if (_ran) return;
    _ran = true;
    unawaited(ConnectivityService.instance.start());
    unawaited(Future<void>(() => tz.initializeTimeZones()));
    unawaited(_guard(oneSignalSettings())); // push set-up asks the server for its app id: never on the critical path
    unawaited(_guard(refreshLanguages()));
    unawaited(_guard(getAppSettingsData()));
    if (appStore.isLoggedIn && sharedPref.getString(TOKEN).validate().isNotEmpty) unawaited(_guard(validateSession()));
    BootTimings.mark('tasks_started');
  }

  static Future<void> _guard(Future<dynamic>? f) async {
    try {
      await f;
    } catch (_) {}
  }

  /// Fresh language texts. The saved ones are already showing.
  static Future<void> refreshLanguages() async {
    final versionNo = sharedPref.getString(CURRENT_LAN_VERSION) ?? LanguageVersion;
    final value = await getLanguageList(versionNo);
    app_update_check = value.rider_version;
    if (value.status != true) {
      final saved = sharedPref.getString(LanguageJsonDataRes) ?? '';
      if (saved.isNotEmpty) {
        final settings = ServerLanguageResponse.fromJson(json.decode(saved.trim()));
        if (settings.data!.isNotEmpty) {
          defaultServerLanguageData = settings.data;
          performLanguageOperation(defaultServerLanguageData);
        }
      }
      return;
    }
    setValue(CURRENT_LAN_VERSION, value.currentVersionNo.toString());
    if (value.data!.isNotEmpty) {
      defaultServerLanguageData = value.data;
      performLanguageOperation(defaultServerLanguageData);
      setValue(LanguageJsonDataRes, value.toJson());
      if (!(sharedPref.getBool(IS_SELECTED_LANGUAGE_CHANGE) ?? false)) {
        for (final l in value.data!) {
          if (l.isDefaultLanguage == 1) {
            setValue(SELECTED_LANGUAGE_CODE, l.languageCode);
            setValue(SELECTED_LANGUAGE_COUNTRY_CODE, l.countryCode);
            appStore.setLanguage(l.languageCode!, context: getContext);
            break;
          }
        }
      }
    } else {
      defaultServerLanguageData = [];
      selectedServerLanguageData = null;
      setValue(LanguageJsonDataRes, "");
    }
  }

  /// Asks the server whether the saved session is still good. Offline or slow: nothing happens, the person keeps
  /// working and every action is still checked by the server. Expired or revoked (401): sign out cleanly.
  static Future<void> validateSession() async {
    final id = sharedPref.getInt(USER_ID);
    if (id == null) return;
    try {
      final r = await DriverApplicationApi.getJson('user-detail?id=$id');
      final d = r['data'];
      if (d is Map) {
        String s(String k) => d[k]?.toString() ?? '';
        if (s('email').isNotEmpty) {
          appStore.setUserEmail(s('email'));
          sharedPref.setString(USER_EMAIL, s('email'));
        }
        if (s('username').isNotEmpty) appStore.setUserName(s('username'));
        if (s('first_name').isNotEmpty) {
          appStore.setFirstName(s('first_name'));
          sharedPref.setString(FIRST_NAME, s('first_name'));
        }
        if (s('last_name').isNotEmpty) sharedPref.setString(LAST_NAME, s('last_name'));
        if (s('referral_code').isNotEmpty) appStore.setReferralCode(s('referral_code'));
        appStore.setUserProfile(s('profile_image'));
        sharedPref.setString(USER_PROFILE_PHOTO, s('profile_image'));
      }
    } on ApiFailure catch (e) {
      if (e.status == 401) {
        await logOutSuccess();
        toast('Your session has ended. Please sign in again.');
      }
    }
  }
}

/// Kept so older references still compile: it simply shows the first screen. The app no longer starts here.
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => bootHome();
}
