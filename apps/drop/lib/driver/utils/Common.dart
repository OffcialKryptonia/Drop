import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:map_launcher/map_launcher.dart' as map;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:drop/driver/utils/Extensions/Loader.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';
import 'package:drop/driver/utils/Images.dart';

import '../main.dart';
import '../model/RideDetailModel.dart';
import '../model/RiderModel.dart';
import '../model/UserDetailModel.dart';
import '../network/RestApis.dart';
import '../screens/ChatScreen.dart';
import '../screens/DashboardScreen.dart';
import '../screens/DocumentsScreen.dart';
import '../screens/RidesListScreen.dart';
import 'Colors.dart';
import 'Constants.dart';
import 'Extensions/AppButtonWidget.dart';
import 'Extensions/app_common.dart';

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

InputDecoration inputDecoration(BuildContext context, {String? label, Widget? prefixIcon, Widget? suffixIcon, String? counterText}) {
  return InputDecoration(
    focusColor: primaryColor,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    counterText: counterText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: Colors.black)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: Colors.red)),
    alignLabelWithHint: true,
    filled: false,
    isDense: true,
    labelText: label ?? "Sample Text",
    labelStyle: primaryTextStyle(),
  );
}

Widget printAmountWidget({required String amount, double? size, Color? color, FontWeight? weight}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim()
        ? [
            Text(
              "${appStore.currencyCode} ",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(fontSize: size ?? textPrimarySizeGlobal, color: color ?? textPrimaryColorGlobal, fontWeight: weight ?? FontWeight.bold, fontFamily: GoogleFonts.roboto().fontFamily),
            ),
            Text(
              "$amount",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(fontSize: size ?? textPrimarySizeGlobal, color: color ?? textPrimaryColorGlobal, fontWeight: weight ?? FontWeight.bold, fontFamily: GoogleFonts.roboto().fontFamily),
            ),
          ]
        : [
            Text(
              "$amount ",
              style: TextStyle(fontSize: size ?? textPrimarySizeGlobal, color: color ?? textPrimaryColorGlobal, fontWeight: weight ?? FontWeight.bold, fontFamily: GoogleFonts.roboto().fontFamily),
            ),
            Text(
              "${appStore.currencyCode}",
              // appStore.currencyPosition.toString().toLowerCase().trim() == LEFT.toLowerCase().trim() ? '${appStore.currencyCode}$amount' : '$amount ${appStore.currencyCode}',
              // textDirection: TextDirection.LTR,
              style: TextStyle(fontSize: size ?? textPrimarySizeGlobal, color: color ?? textPrimaryColorGlobal, fontWeight: weight ?? FontWeight.bold, fontFamily: GoogleFonts.roboto().fontFamily),
            ),
          ],
  );
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

Widget commonCachedNetworkImage(
  String? url, {
  double? height,
  double? width,
  BoxFit? fit,
  AlignmentGeometry? alignment,
  bool usePlaceholderIfUrlEmpty = true,
  double? radius,
}) {
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

List<BoxShadow> defaultBoxShadow({
  Color? shadowColor,
  double? blurRadius,
  double? spreadRadius,
  Offset offset = const Offset(0.0, 0.0),
}) {
  return [
    BoxShadow(
      color: shadowColor ?? Colors.grey.withValues(alpha: 0.2),
      blurRadius: blurRadius ?? 4.0,
      spreadRadius: spreadRadius ?? 1.0,
      offset: offset,
    )
  ];
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
      padding: EdgeInsets.all(10),
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
  print("DATEIS:::${date}");
  return DateFormat('dd MMM yyyy').format(DateTime.parse(date).toLocal()) + " at " + DateFormat('hh:mm a').format(DateTime.parse(date).toLocal());
}

Widget emptyWidget() {
  return Center(child: Image.asset(ic_no_data, width: 150, height: 250));
}

// buttonText({String? status}) {
//   if (status == NEW_RIDE_REQUESTED) {
//     return language.accepted;
//   } else if (status == ACCEPTED || status == BID_ACCEPTED) {
//     return language.arriving;
//   } else if (status == IN_PROGRESS) {
//     return language.endRide;
//   } else if (status == CANCELED) {
//     return language.cancelled;
//   } else if (status == ARRIVING) {
//     return language.arrived;
//   } else if (status == ARRIVED) {
//     return language.startRide;
//   } else {
//     return language.endRide;
//   }
// }

buttonText({String? status, String? paymentType, String? paymentStatus}) {
  if (status == NEW_RIDE_REQUESTED) {
    return language.accepted;
  } else if (status == ACCEPTED || status == BID_ACCEPTED || status == 'assign_driver') {
    return language.arriving;
  } else if (status == IN_PROGRESS) {
    return language.endRide;
  } else if (status == CANCELED) {
    return language.cancelled;
  } else if (status == ARRIVING) {
    return language.arrived;
  } else if (status == ARRIVED) {
    return language.startRide;
  } else if (status == COMPLETED && paymentStatus != PAYMENT_PAID && paymentType == CASH) {
    return language.cashCollected;
  } else if (status == COMPLETED && paymentStatus != PAYMENT_PAID && paymentType != CASH) {
    return language.waitingForDriverConformation;
  } else {
    return status;
  }
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

String statusTypeIconForButton({String? type}) {
  String icon = ic_history_img1;
  if (type == NEW_RIDE_REQUESTED) {
    icon = ic_history_img2;
  } else if (type == ACCEPTED || type == BID_ACCEPTED) {
    icon = ic_history_img3;
  } else if (type == ARRIVING) {
    icon = ic_history_img4;
  } else if (type == ARRIVED) {
    icon = ic_history_img5;
  } else if (type == IN_PROGRESS) {
    icon = ic_history_img7;
  } else if (type == CANCELED) {
    icon = ic_history_img7;
  } else if (type == COMPLETED) {
    // icon = ic_history_img7;
  }
  return icon;
}

String statusName({String? status}) {
  if (status == NEW_RIDE_REQUESTED) {
    status = language.newRideRequested;
  } else if (status == ACCEPTED || status == BID_ACCEPTED || status == 'assign_driver') {
    status = language.accepted;
  } else if (status == ARRIVING) {
    status = language.arriving;
  } else if (status == ARRIVED) {
    status = language.arrived;
  } else if (status == IN_PROGRESS) {
    status = language.inProgress;
  } else if (status == CANCELED) {
    status = language.cancelled;
  } else if (status == COMPLETED) {
    status = language.completed;
  }
  return status!;
}

bool get isRTL => rtlLanguage.contains(appStore.selectedLanguage);

// double calculateDistance(lat1, lon1, lat2, lon2) {
//   var p = 0.017453292519943295;
//   var a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
//   return (12742 * asin(sqrt(a))).toStringAsFixed(digitAfterDecimal).toDouble();
// }

Widget totalCount({String? title, num? amount, bool? isTotal = false, double? space}) {
  if (amount! > 0) {
    return Padding(
      padding: EdgeInsets.only(bottom: space ?? 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(title!, style: isTotal == true ? boldTextStyle(color: Colors.green, size: 18) : secondaryTextStyle())),
          printAmountWidget(amount: amount.toStringAsFixed(digitAfterDecimal), size: isTotal == true ? 18 : 14, color: isTotal == true ? Colors.green : textPrimaryColorGlobal)
          // Text(printAmount(amount!.toStringAsFixed(digitAfterDecimal)), style: isTotal == true ? boldTextStyle(color: Colors.green, size: 18) : boldTextStyle(size: 14)),
        ],
      ),
    );
  } else {
    return SizedBox.shrink();
  }
}

Future<bool> checkPermission() async {
  // Request app level location permission
  LocationPermission locationPermission = await Geolocator.requestPermission();

  if (locationPermission == LocationPermission.whileInUse || locationPermission == LocationPermission.always) {
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

    return true;
  }
}

Future<bool> setValue(String key, dynamic value, {bool print1 = true}) async {
  if (print1) print('${value.runtimeType} - $key - $value');

  if (value is String) {
    return await sharedPref.setString(key, value.validate());
  } else if (value is int) {
    return await sharedPref.setInt(key, value.validate());
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

/// Handle error and loading widget when using FutureBuilder or StreamBuilder
Widget snapWidgetHelper<T>(AsyncSnapshot<T> snap, {Widget? errorWidget, Widget? loadingWidget, String? defaultErrorMessage, @Deprecated('Do not use this') bool checkHasData = false, Widget Function(String)? errorBuilder}) {
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

void showOnlyDropLocationsDialog({
  required BuildContext context,
  required List<MultiDropLocation> multiDropData,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          language.viewDropLocations,
          style: primaryTextStyle(size: 18, weight: FontWeight.w500),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: multiDropData.map((location) {
              return Padding(
                padding: EdgeInsets.only(bottom: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text(location.address ?? ''.validate(), style: primaryTextStyle(size: 14), overflow: TextOverflow.ellipsis, maxLines: 2)),
                        mapRedirectionWidget(latLong: LatLng(location.lat, location.lng))
                      ],
                    ),
                    Divider(
                      height: 10,
                    )
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              language.cancel,
              style: primaryTextStyle(),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}

String changeStatusText(String? status) {
  if (status == COMPLETED) {
    return language.completed;
  } else if (status == CANCELED) {
    return language.cancelled;
  }
  return '';
}

String changeGender(String? name) {
  if (name == MALE) {
    return language.male;
  } else if (name == FEMALE) {
    return language.female;
  } else if (name == OTHER) {
    return language.other;
  }
  return '';
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
  } else if (paymentStatus == Wallet) {
    return language.wallet;
  }
  return language.pending;
}

Widget loaderWidgetLogIn() {
  return Center(
    child: Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ),
    ),
  );
}

Widget earningWidget({String? text, String? image, num? totalAmount}) {
  return Container(
    width: 160,
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 10.0, spreadRadius: 0),
      ],
      color: primaryColor,
      borderRadius: BorderRadius.circular(defaultRadius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text!, style: boldTextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text(totalAmount.toString(), style: boldTextStyle(color: Colors.white)),
          ],
        ),
        Expanded(
          child: SizedBox(width: 8),
        ),
        Container(
          margin: EdgeInsets.only(left: 2),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(defaultRadius)),
          child: Image.asset(image!, fit: BoxFit.cover, height: 40, width: 40),
        )
      ],
    ),
  );
}

Widget earningText({String? title, num? amount, bool? isTotal = false, bool? isRides = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title!, style: isTotal == true ? boldTextStyle(size: 18) : primaryTextStyle()),
      printAmountWidget(amount: amount!.toStringAsFixed(digitAfterDecimal), size: isTotal == true ? 22 : 18, weight: isTotal == true ? FontWeight.bold : FontWeight.normal, color: isTotal == true ? Colors.green : textPrimaryColorGlobal)
    ],
  );
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
    case "ERROR_INVALID_EMAIL":
    case "invalid-email":
      return "Email address is invalid.";
    default:
      return error.message.toString();
  }
}

void showOnlyDropLocationsRiderDialog(BuildContext context, List<MultiDropLocation> dropLocations) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          language.viewDropLocations,
          style: primaryTextStyle(size: 18, weight: FontWeight.w500),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: dropLocations.map((location) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text(location.address ?? ''.validate(), style: primaryTextStyle(size: 14), overflow: TextOverflow.ellipsis, maxLines: 2)),
                      if (location.droppedAt != null)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        )
                    ],
                  ),
                  Divider(
                    height: 10,
                  )
                ],
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              language.close,
              style: primaryTextStyle(),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}

buttonTransportText({String? status, String? paymentType, String? paymentStatus}) {
  print("-------246>>>${status}");
  print("-------247>>>${paymentType}");
  print("-------248>>>${paymentStatus}");
  if (status == NEW_RIDE_REQUESTED) {
    return language.accepted;
  } else if ((status == ACCEPTED || status == BID_ACCEPTED || status == 'assign_driver') && (paymentType == 'cash' && paymentStatus == 'pending')) {
    return 'Cash Collect';
  } else if (status == ACCEPTED || status == BID_ACCEPTED || status == 'assign_driver') {
    // return language.arriving;
    return "language.collectOrder";
  } else if (status == IN_PROGRESS) {
    return language.endRide;
  } else if (status == CANCELED) {
    return language.cancelled;
  } else if (status == ARRIVING) {
    return language.arrived;
  } else if (status == ARRIVED) {
    return language.startRide;
  } else {
    return status;
  }
}

Widget mapRedirectionWidget({required LatLng latLong}) {
  return inkWellWidget(
    onTap: () async {
      final availableMaps = await map.MapLauncher.installedMaps;
      if (availableMaps.length > 1) {
        return showDialog(
          context: getContext,
          builder: (context) {
            return AlertDialog(
              title: Text("${language.chooseMap}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (int i = 0; i < availableMaps.length; i++)
                    inkWellWidget(
                      onTap: () async {
                        await availableMaps[i].showDirections(
                          destination: map.Coords(latLong.latitude, latLong.longitude),
                        );
                      },
                      child: Container(
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: dividerColor), color: appStore.isDarkMode ? scaffoldColorDark : scaffoldColorLight, borderRadius: BorderRadius.circular(defaultRadius)),
                          child: Row(
                            children: [Text("${availableMaps[i].mapName}")],
                          )),
                    ),
                ],
              ),
              actions: [
                AppButtonWidget(
                    text: language.cancel,
                    textStyle: boldTextStyle(color: Colors.white),
                    color: primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                    }),
              ],
            );
          },
        );
      }
      await availableMaps.first.showDirections(
        destination: map.Coords(latLong.latitude, latLong.longitude),
      );
    },
    child: Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(color: !appStore.isDarkMode ? scaffoldColorLight : scaffoldColorDark, borderRadius: BorderRadius.all(radiusCircular(8)), border: Border.all(width: 1, color: dividerColor)),
      child: Image.asset(ic_map_icon),
      width: 30,
      height: 30,
    ),
  );
}

Widget chatCallWidget(IconData icon, {UserData? data}) {
  if (data != null && data.uid != null) {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: dividerColor), color: appStore.isDarkMode ? scaffoldColorDark : scaffoldColorLight, borderRadius: BorderRadius.circular(defaultRadius)),
          child: Icon(icon, size: 18, color: primaryColor),
        ),
        StreamBuilder<int>(
            stream: chatMessageService.getUnReadCount(receiverId: "${data.uid}", senderId: "${sharedPref.getString(UID)}"),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null && snapshot.data! > 0) {
                return Positioned(top: -2, right: 0, child: Lottie.asset(messageDetect, width: 18, height: 18, fit: BoxFit.cover));
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

Future<void> updatePlayerId() async {
  Map req = {
    "player_id": sharedPref.getString(PLAYER_ID),
  };
  updateStatus(req).then((value) {
    log(value.message);
  }).catchError((error) {});
}

Future<void> exportedLog({required String logMessage, required String file_name}) async {
  final downloadsDirectory = Directory('/storage/emulated/0/Download');
  if (!await downloadsDirectory.exists()) {
    await downloadsDirectory.create(recursive: true);
  }
  final filePath = '${downloadsDirectory.path}/${file_name + "${DateTime.now().hour}_${DateTime.now().minute}"}.txt';
  final file = File(filePath);
  try {
    await file.writeAsString(logMessage, mode: FileMode.append);
  } catch (e) {}
}

getSettings() async {
  return await getAppSetting().then((value) {
    sharedPref.setString("reference_amount", value.reference_amount ?? "0");
    sharedPref.setString("reference_type", value.reference_type ?? "fixed");
    sharedPref.setString("maxEarningPerMonth", value.maxEarningPerMonth ?? "0");
    if (value.walletSetting != null) {
      value.walletSetting!.forEach((element) {
        if (element.key == PRESENT_TOPUP_AMOUNT) {
          appStore.setWalletPresetTopUpAmount(element.value ?? PRESENT_TOP_UP_AMOUNT_CONST);
        }
        if (element.key == MIN_AMOUNT_TO_ADD) {
          if (element.value != null) appStore.setMinAmountToAdd(int.parse(element.value!));
        }
        if (element.key == MAX_AMOUNT_TO_ADD) {
          if (element.value != null) appStore.setMaxAmountToAdd(int.parse(element.value!));
        }
      });
    }
    if (value.rideSetting != null) {
      value.rideSetting!.forEach((element) {
        if (element.key == PRESENT_TIP_AMOUNT) {
          appStore.setWalletTipAmount(element.value ?? PRESENT_TOP_UP_AMOUNT_CONST);
        }
        if (element.key == MAX_TIME_FOR_DRIVER_SECOND) {
          REQUEST_TIME_VAL = int.parse(element.value ?? '60');
        }
        if (element.key == APPLY_ADDITIONAL_FEE) {
          appStore.setExtraCharges(element.value ?? '0');
        }
        if (element.key == RIDE_DRIVER_CAN_REVIEW) {
          appStore.setIsShowRiderReview(element.value ?? '0');
        }
        if (element.key == FLIGHT_TRACKING_ENABLE) {
          appStore.setFlightTracking(element.value ?? '0');
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
    if (value.walletSetting != null) {
      appStore.setWalletPresetTopUpAmount(value.walletSetting!.firstWhere((element) => element.key == PRESENT_TOPUP_AMOUNT).value ?? PRESENT_TOP_UP_AMOUNT_CONST);
    }
    // if(driverLocation!=null && driverIcon!=null){
    //   markers.add(
    //     Marker(
    //       markerId: MarkerId("driver"),
    //       position: driverLocation!,
    //       icon: driverIcon,
    //       infoWindow: InfoWindow(title: ''),
    //     ),
    //   );
    // }
    // setState(() {});
  }).catchError((error, stack) {
    // FirebaseCrashlytics.instance.recordError("setting_update_issue::" + error.toString(), stack, fatal: true);
    log('${error.toString()}');
  });
}

oneSignalSettings() async {
  // await Permission.notification.request();
  if (Platform.isAndroid) {
    await Permission.notification.request();
  } else {
    await OneSignal.Notifications.requestPermission(true);
  }
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.Debug.setAlertLevel(OSLogLevel.none);
  OneSignal.consentRequired(false);
  OneSignal.initialize(mOneSignalAppIdDriver);
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.preventDefault();
    event.notification.display();
  });
  await Future.delayed(Duration(seconds: 3));
  saveOneSignalPlayerId();
  if (appStore.isLoggedIn) {
    updatePlayerId();
  }
  OneSignal.Notifications.addClickListener((notification) async {
    notification.notification;
    var notId = notification.notification.additionalData!["id"];
    log("$notId---" + notification.notification.additionalData!['type'].toString());
    var notType = notification.notification.additionalData!['type'];
    if (notType != null && !notId.toString().contains('CHAT')) {
      if (notType == "document_approved") {
        launchScreen(getContext, DocumentsScreen(isShow: true), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        return;
      }
      await rideDetail(rideId: int.tryParse(notId.toString())).then((value) {
        RideDetailModel mRideModel = value;
        if (mRideModel.data!.driverId != null) {
          if (sharedPref.getInt(USER_ID) == mRideModel.data!.driverId) {
            if (mRideModel.data!.paymentStatus == "paid") {
              launchScreen(getContext, RidesListScreen(), isNewTask: true);
            } else {
              launchScreen(getContext, DashboardScreen(), isNewTask: true);
            }
          } else {
            toast("Sorry! You missed this ride");
          }
        }
      }).catchError((error) {
        appStore.setLoading(false);
        log('${error.toString()}');
      });
    }
    if (notId != null) {
      if (notId.toString().contains('CHAT')) {
        UserDetailModel user = await getUserDetail(userId: int.parse(notId.toString().replaceAll("CHAT_", "")));
        launchScreen(
            getContext,
            ChatScreen(
              userData: user.data,
            ),
            isNewTask: true);
      }
    }
  });
}

Future<void> saveOneSignalPlayerId() async {
  OneSignal.User.pushSubscription.addObserver((state) async {
    if (OneSignal.User.pushSubscription.id.validate().isNotEmpty) await sharedPref.setString(PLAYER_ID, OneSignal.User.pushSubscription.id.validate());
  });
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

Future<BitmapDescriptor> getResizedMarker(
  String assetPath,
) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();

  final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetHeight: marker_size_height);
  final ui.FrameInfo fi = await codec.getNextFrame();

  final ByteData? resizedBytes = await fi.image.toByteData(format: ui.ImageByteFormat.png);
  // ignore:deprecated_member_use
  return BitmapDescriptor.fromBytes(resizedBytes!.buffer.asUint8List());
}

Future<BitmapDescriptor> getNetworkImageMarker(String imageUrl) async {
  final http.Response response = await http.get(Uri.parse(imageUrl));
  final Uint8List bytes = response.bodyBytes;
  final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetHeight: marker_size_height);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ByteData? byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List resizedBytes = byteData!.buffer.asUint8List();
  // ignore:deprecated_member_use
  return BitmapDescriptor.fromBytes(resizedBytes);
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

Widget buildInfoTile({
  required IconData icon,
  String? title,
  required String subtitle,
  Widget? title_widget,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    margin: EdgeInsets.only(right: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: Colors.black54),
        SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title_widget != null
                ? title_widget
                : Text(
                    title.validate(),
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    ),
  );
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
