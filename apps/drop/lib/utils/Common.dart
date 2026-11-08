import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../manage_imports.dart';

Widget dotIndicator(list, i) {
  return SizedBox(
    height: 16,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        list.length,
        (ind) {
          return Container(
            height: 8,
            width: 8,
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(color: i == ind ? Colors.white : Colors.grey.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(defaultRadius)),
          );
        },
      ),
    ),
  );
}

InputDecoration inputDecoration(BuildContext context, {String? label, Widget? prefixIcon, Widget? suffixIcon, bool? alignWithHint = true, String? counterText}) {
  return InputDecoration(
    focusColor: primaryColor,
    prefixIcon: prefixIcon,
    counterText: counterText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: Colors.black)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: Colors.red)),
    alignLabelWithHint: alignWithHint,
    filled: false,
    isDense: true,
    labelText: label ?? "Sample Text",
    labelStyle: primaryTextStyle(),
    suffixIcon: suffixIcon,
  );
}

InputDecoration searchInputDecoration({String? hint}) {
  return InputDecoration(
      contentPadding: EdgeInsets.symmetric(vertical: 8),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
      border: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
      focusColor: primaryColor,
      isDense: true,
      hintStyle: primaryTextStyle(),
      labelStyle: primaryTextStyle(),
      hintText: hint);
}

extension BooleanExtensions on bool? {
  /// Validate given bool is not null and returns given value if null.
  bool validate({bool value = false}) => this ?? value;
}

EdgeInsets dynamicAppButtonPadding(BuildContext context) {
  return EdgeInsets.symmetric(vertical: 14, horizontal: 16);
}

Widget inkWellWidget({Function()? onTap, required Widget child}) {
  return InkWell(onTap: onTap, child: child, highlightColor: Colors.transparent, hoverColor: Colors.transparent, splashColor: Colors.transparent);
}

bool get isRTL => rtlLanguage.contains(appStore.selectedLanguage);

Widget commonCachedNetworkImage(String? url, {double? height, double? width, BoxFit? fit, AlignmentGeometry? alignment, bool usePlaceholderIfUrlEmpty = true, double? radius}) {
  if (url != null && url.isEmpty) {
    return placeHolderWidget(height: height, width: width, fit: fit, alignment: alignment, radius: radius);
  } else if (url.validate().startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: url!,
      height: height,
      width: width,
      fit: fit,
      alignment: alignment as Alignment? ?? Alignment.center,
      errorWidget: (_, s, d) {
        return placeHolderWidget(height: height, width: width, fit: fit, alignment: alignment, radius: radius);
      },
      placeholder: (_, s) {
        if (!usePlaceholderIfUrlEmpty) return SizedBox();
        return placeHolderWidget(height: height, width: width, fit: fit, alignment: alignment, radius: radius);
      },
    );
  } else {
    return Image.network(url!, height: height, width: width, fit: fit, alignment: alignment ?? Alignment.center);
  }
}

Widget placeHolderWidget({double? height, double? width, BoxFit? fit, AlignmentGeometry? alignment, double? radius}) {
  return Image.asset(placeholder, height: height, width: width, fit: fit ?? BoxFit.cover, alignment: alignment ?? Alignment.center);
}

/// Hide soft keyboard
void hideKeyboard(context) => FocusScope.of(context).requestFocus(FocusNode());

const double degrees2Radians = pi / 180.0;

double radians(double degrees) => degrees * degrees2Radians;

Future<bool> isNetworkAvailable() async {
  var connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}

String parseHtmlString(String? htmlString) {
  return parse(parse(htmlString).body!.text).documentElement!.text;
}

Widget loaderWidget() {
  return Center(
    child: Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 0, offset: Offset(0.0, 0.0)),
        ],
      ),
      width: 50,
      height: 50,
      child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor),
    ),
  );
}

void afterBuildCreated(Function()? onCreated) {
  makeNullable(SchedulerBinding.instance)!.addPostFrameCallback((_) => onCreated?.call());
}

T? makeNullable<T>(T? value) => value;

String printDate(String date) {
  return DateFormat('dd MMM yyyy').format(DateTime.parse(date).toLocal()) + " at " + DateFormat('hh:mm a').format(DateTime.parse(date).toLocal());
}

Widget emptyWidget() {
  return Center(child: Image.asset(noDataImg, width: 150, height: 250));
}

String statusTypeIcon({String? type}) {
  String icon = ic_history_img1;
  if (type == NEW_RIDE_REQUESTED) {
    icon = ic_history_img1;
  } else if (type == ACCEPTED || type == BID_ACCEPTED) {
    icon = ic_history_img2;
  } else if (type == ARRIVING) {
    icon = ic_history_img3;
  } else if (type == ARRIVED) {
    icon = ic_history_img4;
  } else if (type == IN_PROGRESS) {
    icon = ic_history_img5;
  } else if (type == CANCELED) {
    icon = ic_history_img6;
  } else if (type == COMPLETED) {
    icon = ic_history_img7;
  }
  return icon;
}

Widget scheduleOptionWidget(BuildContext context, bool isSelected, String imagePath, String title) {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(
          color: isSelected
              ? primaryColor
              : appStore.isDarkMode
                  ? Colors.transparent
                  : borderColor),
    ),
    child: Row(
      children: [
        ImageIcon(AssetImage(imagePath), size: 20, color: isSelected ? primaryColor : Colors.grey),
        SizedBox(width: 16),
        Text(title, style: boldTextStyle()),
      ],
    ),
  );
}

Widget totalCount({String? title, num? amount, bool? isTotal = false, double? space}) {
  if (amount! > 0) {
    return Padding(
      padding: EdgeInsets.only(bottom: space ?? 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(title!, style: isTotal == true ? boldTextStyle(color: Colors.green, size: 18) : secondaryTextStyle())),
          printAmountWidget(amount: '${amount.toStringAsFixed(digitAfterDecimal)}', size: isTotal == true ? 18 : 14, color: isTotal == true ? Colors.green : textPrimaryColorGlobal)
        ],
      ),
    );
  } else {
    return SizedBox();
  }
}

Widget printAmountWidget({required String amount, double? size, Color? color, FontWeight? weight, TextDecoration? textDecoration, double? decorationThickness, Color? decorationColor}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    // mainAxisAlignment: MainAxisAlignment.start,
    // crossAxisAlignment: CrossAxisAlignment.center,
    children: appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim()
        ? [
            Text(
              "${appStore.currencyCode} ",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(
                  fontSize: size ?? textPrimarySizeGlobal,
                  color: color ?? textPrimaryColorGlobal,
                  fontWeight: weight ?? FontWeight.bold,
                  fontFamily: GoogleFonts.roboto().fontFamily,
                  decorationThickness: decorationThickness,
                  decorationColor: decorationColor,
                  decoration: textDecoration ?? TextDecoration.none),
            ),
            Text(
              "$amount",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(
                fontSize: size ?? textPrimarySizeGlobal,
                color: color ?? textPrimaryColorGlobal,
                fontWeight: weight ?? FontWeight.bold,
                fontFamily: GoogleFonts.roboto().fontFamily,
                decoration: textDecoration ?? TextDecoration.none,
                decorationThickness: decorationThickness,
                decorationColor: decorationColor,
              ),
            ),
          ]
        : [
            Text(
              "$amount ",
              style: TextStyle(
                fontSize: size ?? textPrimarySizeGlobal,
                color: color ?? textPrimaryColorGlobal,
                fontWeight: weight ?? FontWeight.bold,
                fontFamily: GoogleFonts.roboto().fontFamily,
                decorationThickness: decorationThickness,
                decorationColor: decorationColor,
                decoration: textDecoration ?? TextDecoration.none,
              ),
            ),
            Text(
              "${appStore.currencyCode}",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(
                  fontSize: size ?? textPrimarySizeGlobal,
                  color: color ?? textPrimaryColorGlobal,
                  fontWeight: weight ?? FontWeight.bold,
                  fontFamily: GoogleFonts.roboto().fontFamily,
                  decorationThickness: decorationThickness,
                  decorationColor: decorationColor,
                  decoration: textDecoration ?? TextDecoration.none),
            ),
          ],
  );
}

Widget printAmountWidgetForEstimate({required String amount, required String sign, double? size, Color? color, FontWeight? weight, TextDecoration? textDecoration, double? decorationThickness, Color? decorationColor}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    // mainAxisAlignment: MainAxisAlignment.start,
    // crossAxisAlignment: CrossAxisAlignment.center,
    children: appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim()
        ? [
            Text(
              "$sign ${appStore.currencyCode} ",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(
                  fontSize: size ?? textPrimarySizeGlobal,
                  color: color ?? textPrimaryColorGlobal,
                  fontWeight: weight ?? FontWeight.bold,
                  fontFamily: GoogleFonts.roboto().fontFamily,
                  decorationThickness: decorationThickness,
                  decorationColor: decorationColor,
                  decoration: textDecoration ?? TextDecoration.none),
            ),
            Text(
              "$amount",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(
                fontSize: size ?? textPrimarySizeGlobal,
                color: color ?? textPrimaryColorGlobal,
                fontWeight: weight ?? FontWeight.bold,
                fontFamily: GoogleFonts.roboto().fontFamily,
                decoration: textDecoration ?? TextDecoration.none,
                decorationThickness: decorationThickness,
                decorationColor: decorationColor,
              ),
            ),
          ]
        : [
            Text(
              "$sign $amount ",
              style: TextStyle(
                fontSize: size ?? textPrimarySizeGlobal,
                color: color ?? textPrimaryColorGlobal,
                fontWeight: weight ?? FontWeight.bold,
                fontFamily: GoogleFonts.roboto().fontFamily,
                decorationThickness: decorationThickness,
                decorationColor: decorationColor,
                decoration: textDecoration ?? TextDecoration.none,
              ),
            ),
            Text(
              "${appStore.currencyCode}",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(
                  fontSize: size ?? textPrimarySizeGlobal,
                  color: color ?? textPrimaryColorGlobal,
                  fontWeight: weight ?? FontWeight.bold,
                  fontFamily: GoogleFonts.roboto().fontFamily,
                  decorationThickness: decorationThickness,
                  decorationColor: decorationColor,
                  decoration: textDecoration ?? TextDecoration.none),
            ),
          ],
  );
}

Future<bool> checkPermission() async {
  // Request app level location permission
  LocationPermission locationPermission = await Geolocator.requestPermission();

  if (locationPermission == LocationPermission.whileInUse || locationPermission == LocationPermission.always) {
    await Geolocator.getCurrentPosition().then((value) {
      sharedPref.setDouble(LATITUDE, value.latitude);
      sharedPref.setDouble(LONGITUDE, value.longitude);
    });
    // Check system level location permission
    if (!await Geolocator.isLocationServiceEnabled()) {
      return await Geolocator.openLocationSettings().then((value) => false).catchError((e) => false);
    } else {
      return true;
    }
  } else {
    toast(language.pleaseEnableLocationPermission);

    // Open system level location permission
    await Geolocator.openAppSettings();

    return false;
  }
}

/// Handle error and loading widget when using FutureBuilder or StreamBuilder
Widget snapWidgetHelper<T>(
  AsyncSnapshot<T> snap, {
  Widget? errorWidget,
  Widget? loadingWidget,
  String? defaultErrorMessage,
  @Deprecated('Do not use this') bool checkHasData = false,
  Widget Function(String)? errorBuilder,
}) {
  if (snap.hasError) {
    log(snap.error);
    if (errorBuilder != null) {
      return errorBuilder.call(defaultErrorMessage ?? snap.error.toString());
    }
    return Center(
      child: errorWidget ??
          Text(
            defaultErrorMessage ?? snap.error.toString(),
            style: primaryTextStyle(),
          ),
    );
  } else if (!snap.hasData) {
    return loadingWidget ?? Loader();
  } else {
    return SizedBox();
  }
}

Future<bool> setValue(String key, dynamic value, {bool print1 = true}) async {
  if (print1) print('${value.runtimeType} - $key - $value');

  if (value is String) {
    return await sharedPref.setString(key, value.validate());
  } else if (value is int) {
    return await sharedPref.setInt(key, value);
  } else if (value is bool) {
    return await sharedPref.setBool(key, value.validate());
  } else if (value is double) {
    return await sharedPref.setDouble(key, value);
  } else if (value is Map<String, dynamic>) {
    return await sharedPref.setString(key, jsonEncode(value));
  } else if (value is List<String>) {
    return await sharedPref.setStringList(key, value);
  } else {
    throw ArgumentError('Invalid value ${value.runtimeType} - Must be a String, int, bool, double, Map<String, dynamic> or StringList');
  }
}

String statusName({String? status}) {
  if (status == NEW_RIDE_REQUESTED) {
    status = language.newRideRequested;
  } else if (status == ACCEPTED || status == BID_ACCEPTED || status == 'assign_driver') {
    status = language.accepted;
  } else if (status == ARRIVING) {
    status = language.arriving;
  } else if (status == ASSIGN_DRIVER) {
    status = 'Assign Driver';
  } else if (status == ARRIVED) {
    status = language.arrived;
  } else if (status == IN_PROGRESS) {
    status = language.inProgress;
  } else if (status == CANCELED) {
    status = language.cancelled;
  } else if (status == COMPLETED) {
    status = language.completed;
  }
  return status ?? "";
}

String paymentStatus(String paymentStatus) {
  if (paymentStatus.toLowerCase() == PAYMENT_PENDING.toLowerCase()) {
    return language.pending;
  } else if (paymentStatus.toLowerCase() == PAYMENT_FAILED.toLowerCase()) {
    return language.failed;
  } else if (paymentStatus == PAYMENT_PAID) {
    return language.paid;
  } else if (paymentStatus == CASH) {
    return language.cash;
  } else if (paymentStatus == WALLET) {
    return language.wallet;
  }
  return language.pending;
}

String changeStatusText(String? status) {
  if (status == COMPLETED) {
    return language.completed;
  } else if (status == CANCELED) {
    return language.cancelled;
  }
  return '';
}

String getMessageFromErrorCode(FirebaseException error) {
  switch (error.code) {
    case "ERROR_EMAIL_ALREADY_IN_USE":
    case "account-exists-with-different-credential":
    case "email-already-in-use":
      return "The email address is already in use by another account.";
    case "ERROR_WRONG_PASSWORD":
    case "wrong-password":
      return "Wrong email/password combination.";
    case "ERROR_USER_NOT_FOUND":
    case "user-not-found":
      return "No user found with this email.";
    case "ERROR_USER_DISABLED":
    case "user-disabled":
      return "User disabled.";
    case "ERROR_TOO_MANY_REQUESTS":
    case "operation-not-allowed":
      return "Too many requests to log into this account.";
    case "ERROR_OPERATION_NOT_ALLOWED":
    case "ERROR_INVALID_EMAIL":
    case "invalid-email":
      return "Email address is invalid.";
    default:
      return error.message.toString();
  }
}

Widget socialWidget({String? image, String? text}) {
  return Image.asset(image.validate(), fit: BoxFit.cover, height: 30, width: 30);
}

void scheduleFunction({required DateTime scheduledTime, required Function function}) {
  var d1 = DateTime.parse(DateTime.now().toUtc().toString().replaceAll("Z", ""));
  Duration delay = scheduledTime.difference(d1);
  print("CheckDelay:::${delay.inSeconds}");
  if (delay.isNegative) {
    print("Scheduled time is in the past.");
    return;
  }
  Timer(delay, () {
    function();
  });
  print("Function scheduled to run at $scheduledTime");
}

oneSignalSettings() async {
  await Permission.notification.request();
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.Debug.setAlertLevel(OSLogLevel.none);
  OneSignal.consentRequired(false);

  OneSignal.initialize(mOneSignalAppIdRider);

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.preventDefault();
    event.notification.display();
  });

  saveOneSignalPlayerId();
  if (appStore.isLoggedIn) {
    updatePlayerId();
  }
  OneSignal.Notifications.addClickListener((notification) async {
    var notId = notification.notification.additionalData!["id"];
    log("$notId---" + notification.notification.additionalData!['type'].toString());
    var notType = notification.notification.additionalData!['type'];
    if (notId != null) {
      if (notId.toString().contains('CHAT')) {
        LoginResponse user = await getUserDetail(userId: int.parse(notId.toString().replaceAll("CHAT_", "")));
        launchScreen(
            getContext,
            ChatScreen(
              userData: user.data,
              ride_id: -1,
            ),
            isNewTask: true);
      } else if (notType == SUCCESS) {
        launchScreen(getContext, RideDetailScreen(orderId: notId), isNewTask: true);
      }
    }
  });
}

Widget chatCallWidget(IconData icon, {String? uid}) {
  if (uid != null) {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: dividerColor), color: appStore.isDarkMode ? scaffoldColorDark : scaffoldColorLight, borderRadius: BorderRadius.circular(defaultRadius)),
          child: Icon(icon, size: 18, color: primaryColor),
        ),
        StreamBuilder<int>(
            stream: chatMessageService.getUnReadCount(receiverId: "${uid}", senderId: "${sharedPref.getString(UID)}"),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null && snapshot.data! > 0) {
                // return Positioned(top: -2, right: 0, child: Lottie.asset(messageDetect, width: 18, height: 18, fit: BoxFit.cover));
              }
              return SizedBox();
            })
      ],
    );
  } else {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: dividerColor), color: appStore.isDarkMode ? scaffoldColorDark : scaffoldColorLight, borderRadius: BorderRadius.circular(defaultRadius)),
      child: Icon(icon, size: 18, color: primaryColor),
    );
  }
}

String getTripTypeValue(String val) {
  // 'regular','airport_pickup','airport_drop','zone_wise','zone_to_airport','airport_to_zone'
  if (val == tripTypeRegular) {
    return 'regular';
  } else if (val == tripTypeAirportPickup) {
    return 'airport_pickup';
  } else if (val == tripTypeAirportDropoff) {
    return 'airport_drop';
  } else if (val == tripTypeZoneWise) {
    return 'zone_wise';
  } else if (val == tripTypeZoneToAirport) {
    return 'zone_to_airport';
  } else if (val == tripTypeAirportToZone) {
    return 'airport_to_zone';
  }
  return 'regular';
}

bool isDistanceMoreThan100Meters({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
}) {
  double distanceInMeters = Geolocator.distanceBetween(
    startLat,
    startLng,
    endLat,
    endLng,
  );
  return distanceInMeters > 100;
}

Future<void> saveOneSignalPlayerId() async {
  // await OneSignal.shared.getDeviceState().then((value) async {
  // });
  OneSignal.User.pushSubscription.addObserver((state) async {
    if (OneSignal.User.pushSubscription.id.validate().isNotEmpty) await sharedPref.setString(PLAYER_ID, OneSignal.User.pushSubscription.id.validate());
  });
}

Future<void> exportedLog({required String logMessage, required String file_name}) async {
  return;
}

String getMultiLanguageTripType(String val) {
  // 'regular','airport_pickup','airport_drop','zone_wise','zone_to_airport','airport_to_zone'
  if (val == tripTypeRegular) {
    return language.regular;
  } else if (val == tripTypeAirportPickup) {
    return language.airPickup;
  } else if (val == tripTypeAirportDropoff) {
    return language.airDropOff;
  } else if (val == tripTypeZoneWise) {
    return language.zoneWise;
  } else if (val == tripTypeZoneToAirport) {
    return language.zoneToAir;
  } else if (val == tripTypeAirportToZone) {
    return language.airToZone;
  }
  return language.regular;
}

Color paymentStatusColor(String paymentStatus) {
  Color color = textPrimaryColor;

  switch (paymentStatus) {
    case PAYMENT_PAID:
      color = Colors.green;
    case PAYMENT_FAILED:
      color = Colors.red;
    case PAYMENT_PENDING:
      color = Colors.grey;
  }
  return color;
}

Future<void> getAppSettingsData() async {
  await getAppSetting().then((value) {
    sharedPref.setString("reference_amount", value.reference_amount ?? "0");
    sharedPref.setString("reference_type", value.reference_type ?? "fixed");
    sharedPref.setString("maxEarningPerMonth", value.maxEarningPerMonth ?? "0");
    if (value.walletSetting != null) {
      value.walletSetting!.forEach((element) {
        if (element.key == PRESENT_TOPUP_AMOUNT) {
          appStore.setWalletPresetTopUpAmount(element.value ?? PRESENT_TOP_UP_AMOUNT_CONST);
        }
        if (element.key == MIN_AMOUNT_TO_ADD) {
          if (element.value != null) appStore.setMinAmountToAdd(num.parse(element.value!).round());
        }
        if (element.key == MAX_AMOUNT_TO_ADD) {
          if (element.value != null) appStore.setMaxAmountToAdd(num.parse(element.value!).round());
        }
      });
    }
    if (value.rideSetting != null) {
      value.rideSetting!.forEach((element) {
        if (element.key == PRESENT_TIP_AMOUNT) {
          appStore.setWalletTipAmount(element.value ?? PRESENT_TIP_AMOUNT_CONST);
        }
        if (element.key == RIDE_FOR_OTHER) {
          appStore.setIsRiderForAnother(element.value ?? "0");
        }
        if (element.key == IS_MULTI_DROP) {
          appStore.setisMultiDrop(element.value ?? "0");
        }
        if (element.key == RIDE_IS_SCHEDULE_RIDE) {
          appStore.setisScheduleRide(element.value ?? "0");
        }
        if (element.key == IS_BID_ENABLE) {
          appStore.setisBidEnable(element.value ?? "0");
        }
        // isBidEnable
        if (element.key == MAX_TIME_FOR_RIDER_MINUTE) {
          appStore.setRiderMinutes(element.value ?? '4');
        }
      });
    }
    if (value.currencySetting != null) {
      appStore.setCurrencyCode(value.currencySetting!.symbol ?? currencySymbol);
      appStore.setCurrencyName(value.currencySetting!.code ?? currencyNameConst);
      appStore.setCurrencyPosition(value.currencySetting!.position ?? LEFT);
    }
    if (value.settingModel != null) {
      appStore.settingModel = value.settingModel!;
      if (value.settingModel!.helpSupportUrl != null) appStore.mHelpAndSupport = value.settingModel!.helpSupportUrl!;
    }
    if (value.privacyPolicyModel != null && value.privacyPolicyModel!.value != null) appStore.privacyPolicy = value.privacyPolicyModel!.value!;
    if (value.termsCondition != null && value.termsCondition!.value != null) appStore.termsCondition = value.termsCondition!.value!;
  }).catchError((error, stack) {
    // FirebaseCrashlytics.instance.recordError("setting_update_issue::" + error.toString(), stack, fatal: true);
    log('${error.toString()} STack:::${stack}');
  });
}

// Future<BitmapDescriptor> getResizedMarker(
//   String assetPath,
// ) async {
//   final ByteData data = await rootBundle.load(assetPath);
//   print("----686---${assetPath}");
//
//   final Uint8List bytes = data.buffer.asUint8List();
//   final ui.Codec codec = await ui.instantiateImageCodec(bytes,
//       // targetWidth: marker_size_width, // Resize image width
//       targetHeight: marker_size_height);
//   final ui.FrameInfo fi = await codec.getNextFrame();
//   final ByteData? resizedBytes = await fi.image.toByteData(format: ui.ImageByteFormat.png);
//   // ignore:deprecated_member_use
//   return BitmapDescriptor.fromBytes(resizedBytes!.buffer.asUint8List());
// }

Future<BitmapDescriptor> getResizedMarker(String assetPath, {Color? color}) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();

  final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetHeight: marker_size_height);

  final ui.FrameInfo fi = await codec.getNextFrame();
  final ui.Image image = fi.image;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  final Paint paint = Paint();

  // Apply color only if provided
  if (color != null) {
    paint.colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
  }

  canvas.drawImage(image, Offset.zero, paint);

  final ui.Image newImage = await recorder.endRecording().toImage(image.width, image.height);

  final ByteData? byteData = await newImage.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}

Future<BitmapDescriptor> getNetworkImageMarker(String imageUrl) async {
  final http.Response response = await http.get(Uri.parse(imageUrl));

  final Uint8List bytes = response.bodyBytes;
  final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetHeight: marker_size_height);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ByteData? byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List resizedBytes = byteData!.buffer.asUint8List();

  ///  print("----827---${resizedBytes}");
  // ignore:deprecated_member_use
  return BitmapDescriptor.fromBytes(resizedBytes);
}

String generateNonceData([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

List<LatLng> decodePolyline(String encoded) {
  List<LatLng> polyline = [];
  int index = 0;
  int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    polyline.add(LatLng(lat / 1E5, lng / 1E5));
  }

  return polyline;
}

Widget popupDialog(String title, String message, BuildContext context) {
  return Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Warning Icon
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_rounded,
              color: Colors.red,
              size: 40,
            ),
          ),
          SizedBox(height: 16),

          /// Title
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 12),

          /// Message
          Text(
            message,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 24),

          /// Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                "UNDERSTOOD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
