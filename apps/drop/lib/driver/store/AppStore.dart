import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import '../languageConfiguration/AppLocalizations.dart';
import '../languageConfiguration/BaseLanguage.dart';
import '../languageConfiguration/LanguageDataConstant.dart';
import '../languageConfiguration/LanguageDefaultJson.dart';
import '../main.dart';
import '../model/CurrentRequestModel.dart';
import '../model/SettingModel.dart';
import '../utils/Colors.dart';
import '../utils/Constants.dart';
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
  String isShowRiderReview = '0';

  @observable
  String flightTracking = '0';

  @observable
  String userEmail = '';

  @observable
  String uId = '';

  @observable
  String userName = '';

  @observable
  String userProfile = '';

  @observable
  String firstName = '';

  @observable
  bool isDarkMode = false;

  @observable
  String currency = '';

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
  String? rideSecond;

  @observable
  int? minAmountToAdd;

  @observable
  int? maxAmountToAdd;

  @observable
  String? extraChargeValue;

  @observable
  SettingModel settingModel = SettingModel();

  @observable
  String? privacyPolicy;

  @observable
  String? termsCondition;

  @observable
  String? mHelpAndSupport;

  @observable
  String? referralCode;

  @observable
  OnRideRequest? currentRiderRequest;

  @observable
  // int? isAvailable = 0;

  @action
  Future<void> setFirstName(String? val) async {
    firstName = val!;
  }

  @action
  Future<void> setReferralCode(String? val) async {
    referralCode = val!;
  }

  @action
  Future<void> setIsShowRiderReview(String? val) async {
    isShowRiderReview = val!;
  }

  @action
  Future<void> setFlightTracking(String? val) async {
    flightTracking = val!;
  }

  @action
  Future<void> setExtraCharges(String? val) async {
    extraChargeValue = val;
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
  Future<void> setRiderSecond(String? val) async {
    rideSecond = val;
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
  Future<void> setUId(String val, {bool isInitialization = false}) async {
    uId = val;
    if (!isInitialization) await sharedPref.setString(UID, val);
  }

  @action
  Future<void> setCurrency(String val) async {
    currency = val;
  }

  @action
  Future<void> setUserProfile(String val,
      {bool isInitialization = false}) async {
    userProfile = val;
    if (!isInitialization) await sharedPref.setString(USER_PROFILE_PHOTO, val);
  }

  @action
  Future<void> setUserName(String val, {bool isInitialization = false}) async {
    userName = val;
    if (!isInitialization) await sharedPref.setString(USER_NAME, val);
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
    } catch (e) {}
    language = (await AppLocalizations().load(Locale(selectedLanguage)));
  }
}
