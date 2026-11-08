import '../manage_imports.dart';
import 'package:mobx/mobx.dart';

part 'AppStore.g.dart';

class AppStore = _AppStore with _$AppStore;

abstract class _AppStore with Store {
  @observable
  bool isLoggedIn = false;

  @observable
  bool isLoading = false;

  @observable
  int userId = 0;

  @observable
  String uId = '';

  @observable
  String userEmail = '';

  @observable
  String firstName = '';

  @observable
  String userName = '';

  @observable
  String userProfile = '';

  @observable
  bool isDarkMode = false;

  @observable
  String selectedLanguage = defaultLanguageCode;

  @observable
  String walletPresetTopUpAmount = PRESENT_TOP_UP_AMOUNT_CONST;

  @observable
  String walletPresetTipAmount = PRESENT_TIP_AMOUNT_CONST;

  @observable
  String currencyCode = currencySymbol;

  @observable
  String currencyPosition = LEFT;

  @observable
  String currencyName = currencyNameConst;

  @observable
  String? rideMinutes;

  @observable
  int? minAmountToAdd;

  @observable
  int? maxAmountToAdd;

  @observable
  String? isRiderForAnother = "0";

  @observable
  String? isMultiDrop = "0";

  @observable
  String? isScheduleRide = "0";

  @observable
  String? isBidEnable = "0";

  @observable
  SettingModel settingModel = SettingModel();

  @observable
  String? privacyPolicy;

  @observable
  String? termsCondition;

  @observable
  String? referralCode;

  @observable
  String? mHelpAndSupport;

  @observable
  String? activeServices = "both";

  @action
  Future<void> setReferralCode(String? val) async {
    referralCode = val!;
  }

  @action
  Future<void> setIsRiderForAnother(String? val) async {
    isRiderForAnother = val!;
  }

  @action
  Future<void> setisMultiDrop(String? val) async {
    isMultiDrop = val!;
  }

  @action
  Future<void> setisScheduleRide(String? val) async {
    isScheduleRide = val!;
  }

  @action
  Future<void> setActiveServices(String? val) async {
    activeServices = val!;
  }
  // isScheduleRide

  @action
  Future<void> setisBidEnable(String? val) async {
    isBidEnable = val!;
  }

  @action
  Future<void> setFirstName(String? val) async {
    firstName = val!;
  }

  @action
  Future<void> setMaxAmountToAdd(int? val) async {
    maxAmountToAdd = val;
  }

  @action
  Future<void> setMinAmountToAdd(int? val) async {
    minAmountToAdd = val;
  }

  @action
  Future<void> setRiderMinutes(String? val) async {
    rideMinutes = val;
  }

  @action
  Future<void> setCurrencyName(String val) async {
    currencyName = val;
  }

  @action
  Future<void> setCurrencyCode(String val) async {
    currencyCode = val;
  }

  @action
  Future<void> setCurrencyPosition(String val) async {
    currencyPosition = val;
  }

  @action
  Future<void> setWalletTipAmount(String val) async {
    walletPresetTipAmount = val;
  }

  @action
  Future<void> setWalletPresetTopUpAmount(String val) async {
    walletPresetTopUpAmount = val;
  }

  @action
  Future<void> setUserProfile(String val) async {
    userProfile = val;
  }

  @action
  Future<void> setUserName(String val, {bool isInitialization = false}) async {
    userName = val;
    if (!isInitialization) await sharedPref.setString(USER_NAME, val);
  }

  @action
  Future<void> setUId(String val, {bool isInitialization = false}) async {
    uId = val;
    if (!isInitialization) await sharedPref.setString(UID, val);
  }

  @action
  Future<void> setUserEmail(String val, {bool isInitialization = false}) async {
    userEmail = val;
    if (!isInitialization) await sharedPref.setString(USER_EMAIL, val);
  }

  @action
  Future<void> setUserId(int val, {bool isInitializing = false}) async {
    userId = val;
    if (!isInitializing) await sharedPref.setInt(USER_ID, val);
  }

  @action
  Future<void> setLoading(bool val) async {
    isLoading = val;
  }

  @action
  Future<void> setLoggedIn(bool val, {bool isInitializing = false}) async {
    isLoggedIn = val;
    if (!isInitializing) await sharedPref.setBool(IS_LOGGED_IN, val);
  }

  @action
  Future<void> setDarkMode(bool aIsDarkMode) async {
    isDarkMode = aIsDarkMode;

    if (isDarkMode) {
      textPrimaryColorGlobal = Colors.white;
      textSecondaryColorGlobal = viewLineColor;
      defaultLoaderBgColorGlobal = Colors.black26;
    } else {
      textPrimaryColorGlobal = textPrimaryColor;
      textSecondaryColorGlobal = textSecondaryColor;
      defaultLoaderBgColorGlobal = Colors.white;
    }
  }

  @action
  Future<void> setLanguage(String aCode, {BuildContext? context}) async {
    setDefaultLocate();
    selectedLanguage = aCode;
    try {
      if (context != null) language = BaseLanguage.of(context)!;
    } catch (e) {
      // throw e;
    }
    language = (await AppLocalizations().load(Locale(selectedLanguage)));
  }
}
