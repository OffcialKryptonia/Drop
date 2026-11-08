import 'dart:convert';
import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:mighty_core/utils/core_enum.dart';
import 'package:mighty_core/utils/core_network_utils.dart';
import 'package:drop/driver/model/DocumentListModel.dart';
import 'package:drop/driver/model/PayoutRecord.dart';
import 'package:drop/driver/model/PolyLineData.dart';
import 'package:drop/driver/model/VirtualAccountModel.dart';
import 'package:drop/driver/model/ReferralHistoryListModel.dart';
import 'package:drop/driver/model/ReviewsModel.dart';
import 'package:drop/driver/model/RideDetailModel.dart';
import 'package:drop/driver/model/RiderListModel.dart';
import 'package:drop/driver/model/UserDetailModel.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

import '../languageConfiguration/ServerLanguageResponse.dart';
import '../main.dart';
import '../model/AdditionalFeesList.dart';
import '../model/AppSettingModel.dart';
import '../model/CancleListResponse.dart';
import '../model/ChangePasswordResponseModel.dart';
import '../model/ComplaintCommentModel.dart';
import '../model/ContactNumberListModel.dart';
import '../model/CurrentRequestModel.dart';
import '../model/DriverDocumentList.dart';
import '../model/EarningListModelWeek.dart';
import '../model/LDBaseResponse.dart';
import '../model/LoginResponse.dart';
import '../model/ModelFAQ.dart';
import '../model/NotificationListModel.dart';
import '../model/PaymentListModel.dart';
import '../model/ProfileUpdateModel.dart';
import '../model/ServiceModel.dart';
import '../model/WalletDetailModel.dart';
import '../model/WalletListModel.dart';
import '../model/WithDrawListModel.dart';
import '../model/rewardsListModel.dart';
import '../screens/SignInScreen.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_common.dart';

Future<LoginResponse> signUpApi(Map request) async {
  return parseModel(
    apiCall: executeRequest('driver-register', method: HttpMethods.POST, request: request),
    fromJson: (json) => LoginResponse.fromJson(json),
  ).then((loginResponse) async {
    if (loginResponse.data!.loginType == LoginTypeOTP) {
      await sharedPref.setString(TOKEN, loginResponse.data!.apiToken.validate());
      await sharedPref.setString(USER_TYPE, loginResponse.data!.userType.validate());
      await sharedPref.setString(FIRST_NAME, loginResponse.data!.firstName.validate());
      await sharedPref.setString(LAST_NAME, loginResponse.data!.lastName.validate());
      await sharedPref.setString(CONTACT_NUMBER, loginResponse.data!.contactNumber.validate());
      await sharedPref.setString(USER_EMAIL, loginResponse.data!.email.validate());
      await sharedPref.setString(USER_NAME, loginResponse.data!.username.validate());
      await sharedPref.setString(ADDRESS, loginResponse.data!.address.validate());
      await sharedPref.setInt(USER_ID, loginResponse.data!.id ?? 0);
      await sharedPref.setString(GENDER, loginResponse.data!.gender.validate());
      await sharedPref.setInt(IS_ONLINE, loginResponse.data!.isOnline ?? 0);
      await sharedPref.setString(UID, loginResponse.data!.uid.validate());
      await sharedPref.setString(LOGIN_TYPE, loginResponse.data!.loginType.validate());
      await sharedPref.setInt(IS_Verified_Driver, loginResponse.data!.isVerifiedDriver ?? 0);
      await appStore.setReferralCode(loginResponse.data!.referralCode.validate());
      await appStore.setLoggedIn(true);
      await appStore.setUserEmail(loginResponse.data!.email.validate());
      await appStore.setUserProfile(loginResponse.data!.profileImage.validate());
      MightyCore().configure(authToken: loginResponse.data!.apiToken.validate());
    }
    return loginResponse;
  }).catchError((e) {
    toast(e.toString());
    return e;
  });
}

Future<LoginResponse> logInApi(Map request, {bool isSocialLogin = false}) async {
  return parseModel(
    apiCall: executeRequest(isSocialLogin ? 'social-login' : 'login', method: HttpMethods.POST, request: request),
    fromJson: (json) => LoginResponse.fromJson(json),
  ).then((loginResponse) async {
    if (loginResponse.data != null) {
      await sharedPref.setString(TOKEN, loginResponse.data!.apiToken.validate());
      await sharedPref.setString(USER_TYPE, loginResponse.data!.userType.validate());
      await sharedPref.setString(FIRST_NAME, loginResponse.data!.firstName.validate());
      await sharedPref.setString(LAST_NAME, loginResponse.data!.lastName.validate());
      await sharedPref.setString(CONTACT_NUMBER, loginResponse.data!.contactNumber.validate());
      await sharedPref.setString(USER_EMAIL, loginResponse.data!.email.validate());
      await sharedPref.setString(USER_NAME, loginResponse.data!.username.validate());
      await sharedPref.setString(ADDRESS, loginResponse.data!.address.validate());
      await sharedPref.setInt(USER_ID, loginResponse.data!.id ?? 0);
      await sharedPref.setString(GENDER, loginResponse.data!.gender.validate());
      if (loginResponse.data!.isOnline != null) await sharedPref.setInt(IS_ONLINE, loginResponse.data!.isOnline ?? 0);
      await sharedPref.setInt(IS_Verified_Driver, loginResponse.data!.isVerifiedDriver ?? 0);
      if (loginResponse.data!.uid != null) await sharedPref.setString(UID, loginResponse.data!.uid.validate());
      await sharedPref.setString(LOGIN_TYPE, loginResponse.data!.loginType.validate());
      await appStore.setReferralCode(loginResponse.data!.referralCode.validate());
      await appStore.setLoggedIn(true);
      await appStore.setUserEmail(loginResponse.data!.email.validate());
      await appStore.setUserProfile(loginResponse.data!.profileImage.validate());
      MightyCore().configure(authToken: loginResponse.data!.apiToken.validate());
    }
    return loginResponse;
  }).catchError((e) {
    throw e.toString();
  });
}

// Future<MultipartRequest> getMultiPartRequest(String endPoint, {String? baseUrl}) async {
//   String url = '${baseUrl ?? buildCoreBaseUrl(endPoint).toString()}';
//   log(url);
//   return MultipartRequest('POST', Uri.parse(url));
// }
//
// Future sendMultiPartRequest(MultipartRequest multiPartRequest, {Function(dynamic)? onSuccess, Function(dynamic)? onError}) async {
//   multiPartRequest.headers.addAll(await buildCoreHeaderTokens());
//
//   await multiPartRequest.send().then((res) async {
//     if (res.statusCode == 200) {
//       res.stream.transform(Utf8Decoder()).transform(LineSplitter()).listen((value) {
//         if (value.contains("Server Error")) {
//           onError?.call("Server Error");
//         } else {
//           onSuccess?.call(jsonDecode(value));
//         }
//       });
//     } else {
//       String errorBody = await res.stream.bytesToString();
//       dynamic finalError;
//       try {
//         finalError = jsonDecode(errorBody);
//       } catch (e) {
//         finalError = errorBody;
//       }
//       onError?.call(finalError['message']);
//     }
//   }).catchError((error) {
//     onError?.call(error.toString());
//   });
// }

/// Profile Update
// Future updateProfile({String? firstName, String? lastName, String? userEmail, String? contactNumber, File? file, String? uid, String? carModel, String? carColor, String? carPlateNumber, String? carProduction, String? country_code, int? serviceId}) async {
//   MultipartRequest multiPartRequest = await getMultiPartRequest('update-profile');
//   if (country_code != null) {
//     multiPartRequest.fields['country_code'] = country_code.toString();
//   }
//   multiPartRequest.fields['username'] = sharedPref.getString(USER_NAME).validate();
//   multiPartRequest.fields['email'] = userEmail ?? appStore.userEmail;
//   multiPartRequest.fields['first_name'] = firstName.validate();
//   multiPartRequest.fields['last_name'] = lastName.validate();
//   multiPartRequest.fields['contact_number'] = contactNumber.validate();
//   if (uid != null) multiPartRequest.fields['uid'] = uid.validate();
//   if (carModel.validate().isNotEmpty) multiPartRequest.fields['user_detail[car_model]'] = carModel.validate();
//   if (carColor.validate().isNotEmpty) multiPartRequest.fields['user_detail[car_color]'] = carColor.validate();
//   if (carPlateNumber.validate().isNotEmpty) multiPartRequest.fields['user_detail[car_plate_number]'] = carPlateNumber.validate();
//   if (carProduction.validate().isNotEmpty) multiPartRequest.fields['user_detail[car_production_year]'] = carProduction.validate();
//   if (serviceId != null) multiPartRequest.fields['service_id'] = '$serviceId';
//   multiPartRequest.fields['player_id'] = sharedPref.getString(PLAYER_ID).toString();
//
//   if (file != null) multiPartRequest.files.add(await MultipartFile.fromPath('profile_image', file.path));
//
//   await sendMultiPartRequest(multiPartRequest, onSuccess: (data) async {
//     if (data != null) {
//       ProfileUpdate res = ProfileUpdate.fromJson(data);
//       if (res.data != null) {
//         await sharedPref.setString(FIRST_NAME, res.data!.firstName.validate());
//         await sharedPref.setString(LAST_NAME, res.data!.lastName.validate());
//         await sharedPref.setString(USER_NAME, res.data!.username.validate());
//         await sharedPref.setString(USER_ADDRESS, res.data!.address.validate());
//         await sharedPref.setString(CONTACT_NUMBER, res.data!.contactNumber.validate());
//         await sharedPref.setString(GENDER, res.data!.gender.validate());
//         await appStore.setUserEmail(res.data!.email.validate());
//         if (res.data!.loginType != LoginTypeGoogle) await appStore.setUserProfile(res.data!.profileImage.validate());
//       }
//     }
//   }, onError: (error) {
//     toast(error.toString());
//   });
// }

Future updateProfile({String? firstName, String? lastName, String? userEmail, String? contactNumber, File? file, String? uid, String? carModel, String? carColor, String? carPlateNumber, String? carProduction, String? country_code, int? serviceId}) async {
  Map<String, File> files = {};
  if (file != null) files['profile_image'] = file;

  Map<String, dynamic> fields = {
    'id': sharedPref.getInt(USER_ID).toString(),
    'username': sharedPref.getString(USER_NAME).validate(),
    'email': userEmail ?? appStore.userEmail,
    'first_name': firstName.validate(),
    'last_name': lastName.validate(),
    'contact_number': contactNumber.validate(),
    'player_id': sharedPref.getString(PLAYER_ID).toString(),
  };

  if (uid != null) fields['uid'] = uid;
  if (country_code != null) fields['country_code'] = country_code;

  if (carModel.validate().isNotEmpty) {
    fields['user_detail[car_model]'] = carModel;
  }
  if (carColor.validate().isNotEmpty) {
    fields['user_detail[car_color]'] = carColor;
  }
  if (carPlateNumber.validate().isNotEmpty) {
    fields['user_detail[car_plate_number]'] = carPlateNumber;
  }
  if (carProduction.validate().isNotEmpty) {
    fields['user_detail[car_production_year]'] = carProduction;
  }
  if (serviceId != null) {
    fields['service_id'] = serviceId.toString();
  }

  return parseModel(
    apiCall: executeRequest(
      'update-profile',
      method: HttpMethods.POST,
      fields: fields,
      files: files,
    ),
    fromJson: (json) => ProfileUpdate.fromJson(json),
  ).then((res) async {
    if (res.data != null) {
      await sharedPref.setString(FIRST_NAME, res.data!.firstName.validate());
      await sharedPref.setString(LAST_NAME, res.data!.lastName.validate());
      await sharedPref.setString(USER_NAME, res.data!.username.validate());
      await sharedPref.setString(USER_ADDRESS, res.data!.address.validate());
      await sharedPref.setString(CONTACT_NUMBER, res.data!.contactNumber.validate());
      await sharedPref.setString(GENDER, res.data!.gender.validate());

      await appStore.setUserEmail(res.data!.email.validate());

      if (res.data!.loginType != LoginTypeGoogle) {
        await appStore.setUserProfile(res.data!.profileImage.validate());
      }
    }
  }).catchError((error) {
    toast(error.toString());
  });
}

Future<void> logout({bool isDelete = false}) async {
  if (!isDelete) {
    await logoutApi().then((value) async {
      logOutSuccess();
    }).catchError((e) {
      throw e.toString();
    });
  } else {
    logOutSuccess();
  }
}

Future<ChangePasswordResponseModel> changePassword(Map req) async {
  return parseModel(
    apiCall: executeRequest('change-password', method: HttpMethods.POST, request: req),
    fromJson: (json) => ChangePasswordResponseModel.fromJson(json),
  );
}

Future<ChangePasswordResponseModel> forgotPassword(Map req) async {
  return parseModel(
    apiCall: executeRequest('forget-password', method: HttpMethods.POST, request: req),
    fromJson: (json) => ChangePasswordResponseModel.fromJson(json),
  );
}

Future<ServiceModel> getServices() async {
  return parseModel(
    apiCall: executeRequest('service-list', method: HttpMethods.GET),
    fromJson: (json) => ServiceModel.fromJson(json),
  );
}

Future<UserDetailModel> getUserDetail({int? userId}) async {
  return parseModel(
    apiCall: executeRequest('user-detail?id=$userId', method: HttpMethods.GET),
    fromJson: (json) => UserDetailModel.fromJson(json),
  );
}

Future<LDBaseResponse> changeStatus(Map request) async {
  return parseModel(
    apiCall: executeRequest('update-user-status', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> saveBooking(Map request) async {
  return parseModel(
    apiCall: executeRequest('update-user-status', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<WalletListModel> getWalletList({required int pageData}) async {
  return parseModel(
    apiCall: executeRequest('wallet-list?page=$pageData', method: HttpMethods.GET),
    fromJson: (json) => WalletListModel.fromJson(json),
  );
}

/// The driver's own bank account number for wallet top-ups by transfer.
Future<VirtualAccountModel> getWalletVirtualAccount() async {
  return parseModel(
    apiCall: executeRequest('wallet/virtual-account', method: HttpMethods.GET),
    fromJson: (json) => VirtualAccountModel.fromJson(json),
  );
}

Future<PaymentListModel> getPaymentList() async {
  return parseModel(
    apiCall: executeRequest('payment-gateway-list?status=1', method: HttpMethods.GET),
    fromJson: (json) => PaymentListModel.fromJson(json),
  );
}

Future<LDBaseResponse> saveWallet(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-wallet', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> saveSOS(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-sos', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<ContactNumberListModel> getSosList({int? regionId, int? page}) async {
  return parseModel(
    apiCall: executeRequest(regionId != null ? 'sos-list?region_id=$regionId' : 'sos-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => ContactNumberListModel.fromJson(json),
  );
}

Future<ContactNumberListModel> deleteSosList({int? id}) async {
  return parseModel(
    apiCall: executeRequest('sos-delete/$id', method: HttpMethods.POST),
    fromJson: (json) => ContactNumberListModel.fromJson(json),
  );
}

Future<WithDrawListModel> getWithDrawList({int? page}) async {
  return parseModel(
    apiCall: executeRequest('withdrawrequest-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => WithDrawListModel.fromJson(json),
  );
}

Future<LDBaseResponse> saveWithDrawRequest(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-withdrawrequest', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<AppSettingModel> getAppSetting() async {
  return parseModel(
    apiCall: executeRequest('admin-dashboard', method: HttpMethods.GET),
    fromJson: (json) => AppSettingModel.fromJson(json),
  );
}

Future<RiderListModel> getRiderRequestList({int? page, String? status, LatLng? sourceLatLog, int? driverId}) async {
  return parseModel(
    apiCall: executeRequest(
      sourceLatLog != null
          ? 'riderequest-list?page=$page&driver_id=$driverId'
          : status != null
              ? 'riderequest-list?page=$page&status=$status&driver_id=$driverId'
              : 'riderequest-list?page=$page&driver_id=$driverId',
      method: HttpMethods.GET,
    ),
    fromJson: (json) => RiderListModel.fromJson(json),
  );
}

Future<ServerLanguageResponse> getLanguageList(versionNo) async {
  return parseModel(
    apiCall: executeRequest('language-table-list?version_no=$versionNo', method: HttpMethods.GET),
    fromJson: (json) => ServerLanguageResponse.fromJson(json),
  );
}

Future<DocumentListModel> getDocumentList() async {
  return parseModel(
    apiCall: executeRequest('document-list', method: HttpMethods.GET),
    fromJson: (json) => DocumentListModel.fromJson(json),
  );
}

Future<DriverDocumentList> getDriverDocumentList() async {
  return parseModel(
    apiCall: executeRequest('driver-document-list', method: HttpMethods.GET),
    fromJson: (json) => DriverDocumentList.fromJson(json),
  );
}

/// Profile Update
// Future uploadDocument({int? driverId, int? documentId, File? file, int? isExpire}) async {
//   MultipartRequest multiPartRequest = await getMultiPartRequest('driver-document-save');
//   multiPartRequest.fields['driver_id'] = driverId.toString();
//   multiPartRequest.fields['document_id'] = documentId.toString();
//   multiPartRequest.fields['is_verified'] = '0';
//   if (isExpire != null) multiPartRequest.fields['is_verified'] = '0';
//   if (file != null) multiPartRequest.files.add(await MultipartFile.fromPath('driver_document', file.path));
//
//   await sendMultiPartRequest(multiPartRequest, onSuccess: (data) async {
//     if (data != null) {
//       //
//     }
//   }, onError: (error) {
//     toast(error.toString());
//   });
// }

Future uploadDocument({int? driverId, int? documentId, File? file, int? isExpire}) async {
  Map<String, File> files = {};
  if (file != null) files['driver_document'] = file;

  Map<String, dynamic> fields = {
    'driver_id': driverId.toString(),
    'document_id': documentId.toString(),
    'is_verified': '0',
  };

  if (isExpire != null) {
    fields['is_verified'] = '0';
  }

  return executeRequest(
    'driver-document-save',
    method: HttpMethods.POST,
    fields: fields,
    files: files,
  ).then((res) {
    if (res != null) {
      // handle success if needed
    }
  }).catchError((error) {
    toast(error.toString());
  });
}

Future<LDBaseResponse> deleteDeliveryDoc(int id) async {
  return parseModel(
    apiCall: executeRequest('driver-document-delete/$id', method: HttpMethods.POST),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LoginResponse> updateStatus(Map request) async {
  return parseModel(
    apiCall: executeRequest('update-user-status', method: HttpMethods.POST, request: request),
    fromJson: (json) => LoginResponse.fromJson(json),
  );
}

/// Update Vehicle Info
// Future updateVehicleDetail({String? carModel, String? carColor, String? carPlateNumber, String? carProduction}) async {
//   MultipartRequest multiPartRequest = await getMultiPartRequest('update-profile');
//   multiPartRequest.fields['id'] = sharedPref.getInt(USER_ID).toString();
//   multiPartRequest.fields['email'] = sharedPref.getString(USER_EMAIL).validate();
//   multiPartRequest.fields['contact_number'] = sharedPref.getString(CONTACT_NUMBER).validate();
//   multiPartRequest.fields['username'] = sharedPref.getString(USER_NAME).validate();
//   multiPartRequest.fields['user_detail[car_model]'] = carModel.validate();
//   multiPartRequest.fields['user_detail[car_color]'] = carColor.validate();
//   multiPartRequest.fields['user_detail[car_plate_number]'] = carPlateNumber.validate();
//   multiPartRequest.fields['user_detail[car_production_year]'] = carProduction.validate();
//
//   await sendMultiPartRequest(multiPartRequest, onSuccess: (data) async {
//     if (data != null) {
//       //
//     }
//   }, onError: (error) {
//     toast(error.toString());
//   });
// }

Future updateVehicleDetail({
  String? carModel,
  String? carColor,
  String? carPlateNumber,
  String? carProduction,
}) async {
  Map<String, File> files = {};

  Map<String, dynamic> fields = {
    'id': sharedPref.getInt(USER_ID).toString(),
    'email': sharedPref.getString(USER_EMAIL).validate(),
    'contact_number': sharedPref.getString(CONTACT_NUMBER).validate(),
    'username': sharedPref.getString(USER_NAME).validate(),
  };

  if (carModel.validate().isNotEmpty) {
    fields['user_detail[car_model]'] = carModel;
  }
  if (carColor.validate().isNotEmpty) {
    fields['user_detail[car_color]'] = carColor;
  }
  if (carPlateNumber.validate().isNotEmpty) {
    fields['user_detail[car_plate_number]'] = carPlateNumber;
  }
  if (carProduction.validate().isNotEmpty) {
    fields['user_detail[car_production_year]'] = carProduction;
  }

  return executeRequest(
    'update-profile',
    method: HttpMethods.POST,
    fields: fields,
    files: files,
  ).then((res) {
    if (res != null) {
      // handle success if needed
    }
  }).catchError((error) {
    toast(error.toString());
  });
}

/// Update Bank Info
// Future updateBankDetail({String? bankName, String? bankCode, String? accountName, String? accountNumber, String? routing, String? iban, String? swift}) async {
//   MultipartRequest multiPartRequest = await getMultiPartRequest('update-profile');
//   multiPartRequest.fields['email'] = sharedPref.getString(USER_EMAIL).validate();
//   multiPartRequest.fields['contact_number'] = sharedPref.getString(CONTACT_NUMBER).validate();
//   multiPartRequest.fields['username'] = sharedPref.getString(USER_NAME).validate();
//   multiPartRequest.fields['user_bank_account[bank_name]'] = bankName.validate();
//   multiPartRequest.fields['user_bank_account[bank_code]'] = bankCode.validate();
//   multiPartRequest.fields['user_bank_account[account_holder_name]'] = accountName.validate();
//   multiPartRequest.fields['user_bank_account[account_number]'] = accountNumber.validate();
//   multiPartRequest.fields['user_bank_account[routing_number]'] = routing.validate();
//   multiPartRequest.fields['user_bank_account[bank_iban]'] = iban.validate();
//   multiPartRequest.fields['user_bank_account[bank_swift]'] = swift.validate();
//
//   await sendMultiPartRequest(multiPartRequest, onSuccess: (data) async {
//     if (data != null) {
//       //
//     }
//   }, onError: (error) {
//     toast(error.toString());
//   });
// }

Future updateBankDetail({String? bankName, String? bankCode, String? accountName, String? accountNumber, String? routing, String? iban, String? swift}) async {
  Map<String, File> files = {};

  Map<String, dynamic> fields = {
    'email': sharedPref.getString(USER_EMAIL).validate(),
    'contact_number': sharedPref.getString(CONTACT_NUMBER).validate(),
    'username': sharedPref.getString(USER_NAME).validate(),
  };

  if (bankName.validate().isNotEmpty) {
    fields['user_bank_account[bank_name]'] = bankName;
  }
  if (bankCode.validate().isNotEmpty) {
    fields['user_bank_account[bank_code]'] = bankCode;
  }
  if (accountName.validate().isNotEmpty) {
    fields['user_bank_account[account_holder_name]'] = accountName;
  }
  if (accountNumber.validate().isNotEmpty) {
    fields['user_bank_account[account_number]'] = accountNumber;
  }
  if (routing.validate().isNotEmpty) {
    fields['user_bank_account[routing_number]'] = routing;
  }
  if (iban.validate().isNotEmpty) {
    fields['user_bank_account[bank_iban]'] = iban;
  }
  if (swift.validate().isNotEmpty) {
    fields['user_bank_account[bank_swift]'] = swift;
  }

  return executeRequest(
    'update-profile',
    method: HttpMethods.POST,
    fields: fields,
    files: files,
  ).then((res) {
    if (res != null) {
      // handle success if needed
    }
  }).catchError((error) {
    toast(error.toString());
  });
}

Future<LDBaseResponse> responseBidListing(Map request) async {
  return parseModel(
    apiCall: executeRequest('riderequest-bid-respond', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<CurrentRequestModel> getCurrentRideRequest() async {
  return parseModel(
    apiCall: executeRequest('current-riderequest', method: HttpMethods.GET),
    fromJson: (json) => CurrentRequestModel.fromJson(json),
  );
}

Future<LDBaseResponse> rideRequestUpdate({required Map request, int? rideId}) async {
  return parseModel(
    apiCall: executeRequest('riderequest-update/$rideId', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> applyBid({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('apply-bid', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> ratingReview({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('save-ride-rating', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<AdditionalFeesList> getAdditionalFees() async {
  return parseModel(
    apiCall: executeRequest('additional-fees-list?status=1', method: HttpMethods.GET),
    fromJson: (json) => AdditionalFeesList.fromJson(json),
  );
}

Future<LDBaseResponse> adminNotify({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('admin-sos-notify', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<RideDetailModel> rideDetail({required int? rideId}) async {
  return parseModel(
    apiCall: executeRequest('riderequest-detail?id=$rideId', method: HttpMethods.GET),
    fromJson: (json) => RideDetailModel.fromJson(json),
  );
}

Future<LDBaseResponse> saveComplain({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('save-complaint', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> completeRide({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('complete-riderequest', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> savePayment(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-payment', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> rideRequestResPond({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('riderequest-respond', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<dynamic> dropOupUpdate({required String rideId, required String dropIndex}) async {
  return parseModel(
    apiCall: executeRequest('riderequest/$rideId/drop/$dropIndex', method: HttpMethods.POST),
    fromJson: (json) => json,
  );
}

/// Get Notification List
Future<NotificationListModel> getNotification({required int page}) async {
  return parseModel(
    apiCall: executeRequest('notification-list?page=$page&limit=$PER_PAGE', method: HttpMethods.POST),
    fromJson: (json) => NotificationListModel.fromJson(json),
  );
}

Future<LDBaseResponse> deleteUser() async {
  return parseModel(
    apiCall: executeRequest('delete-user-account', method: HttpMethods.POST),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<EarningListModelWeek> earningList({Map? req}) async {
  return parseModel(
    apiCall: executeRequest('earning-list', method: HttpMethods.POST, request: req),
    fromJson: (json) => EarningListModelWeek.fromJson(json),
  );
}

// Future updateProfileUid() async {
//   MultipartRequest multiPartRequest = await getMultiPartRequest('update-profile');
//   multiPartRequest.fields['id'] = sharedPref.getInt(USER_ID).toString();
//   multiPartRequest.fields['username'] = sharedPref.getString(USER_NAME).validate();
//   multiPartRequest.fields['email'] = sharedPref.getString(USER_EMAIL).validate();
//   multiPartRequest.fields['uid'] = sharedPref.getString(UID).toString();
//
//   log('multipart request:${multiPartRequest.fields}');
//   log(sharedPref.getString(UID).toString());
//
//   await sendMultiPartRequest(multiPartRequest, onSuccess: (data) async {
//     if (data != null) {
//       //
//     }
//   }, onError: (error) {
//     toast(error.toString());
//   });
// }

Future updateProfileUid() async {
  Map<String, File> files = {};

  Map<String, dynamic> fields = {
    'id': sharedPref.getInt(USER_ID).toString(),
    'username': sharedPref.getString(USER_NAME).validate(),
    'email': sharedPref.getString(USER_EMAIL).validate(),
    'uid': sharedPref.getString(UID).toString(),
  };

  log('request fields: $fields');
  log(sharedPref.getString(UID).toString());

  return executeRequest(
    'update-profile',
    method: HttpMethods.POST,
    fields: fields,
    files: files,
  ).then((res) {
    if (res != null) {
      // handle success if needed
    }
  }).catchError((error) {
    toast(error.toString());
  });
}

Future<WalletDetailModel> walletDetailApi() async {
  return parseModel(
    apiCall: executeRequest('wallet-detail', method: HttpMethods.GET),
    fromJson: (json) => WalletDetailModel.fromJson(json),
  );
}

Future<LDBaseResponse> complaintComment({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('save-complaintcomment', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<ComplaintCommentModel> complaintList({required int complaintId, required int currentPage}) async {
  return parseModel(
    apiCall: executeRequest('complaintcomment-list?complaint_id=$complaintId&page=$currentPage', method: HttpMethods.GET),
    fromJson: (json) => ComplaintCommentModel.fromJson(json),
  );
}

Future<LDBaseResponse> logoutApi() async {
  return parseModel(
    apiCall: executeRequest('logout?clear=player_id', method: HttpMethods.GET),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

logOutSuccess() async {
  sharedPref.remove(FIRST_NAME);
  sharedPref.remove(LAST_NAME);
  sharedPref.remove(USER_PROFILE_PHOTO);
  sharedPref.remove(USER_NAME);
  sharedPref.remove(USER_ADDRESS);
  sharedPref.remove(CONTACT_NUMBER);
  sharedPref.remove(GENDER);
  sharedPref.remove(UID);
  sharedPref.remove(TOKEN);
  sharedPref.remove(USER_TYPE);
  sharedPref.remove(ADDRESS);
  sharedPref.remove(USER_ID);
  appStore.setLoggedIn(false);
  if (!(sharedPref.getBool(REMEMBER_ME) ?? false) || sharedPref.getString(LOGIN_TYPE) == LoginTypeGoogle || sharedPref.getString(LOGIN_TYPE) == LoginTypeOTP) {
    sharedPref.remove(USER_EMAIL);
    sharedPref.remove(USER_PASSWORD);
    sharedPref.remove(REMEMBER_ME);
  }
  sharedPref.remove(LOGIN_TYPE);
  sharedPref.remove(LATITUDE);
  sharedPref.remove(LONGITUDE);
  launchScreen(getContext, SignInScreen(), isNewTask: true);
}

Future<AppSettingModel> getAppSettingApi() async {
  return parseModel(
    apiCall: executeRequest('appsetting', method: HttpMethods.GET),
    fromJson: (json) => AppSettingModel.fromJson(json),
  );
}

Future<RewardsListModel> getRewardsList({int? page}) async {
  return parseModel(
    apiCall: executeRequest('reward-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => RewardsListModel.fromJson(json),
  );
}

Future<ReferralHistoryListModel> getReferralList({int? page}) async {
  return parseModel(
    apiCall: executeRequest('reference-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => ReferralHistoryListModel.fromJson(json),
  );
}

/// Get cancel Reason
Future<CancleListResponse> getCancelReason({required String type}) async {
  return parseModel(
    apiCall: executeRequest('cancelReason-list?type=$type', method: HttpMethods.GET),
    fromJson: (json) => CancleListResponse.fromJson(json),
  );
}

Future<ModelFAQ> getFaqList({required int page}) async {
  return parseModel(
    apiCall: executeRequest('faq-list?type=driver&page=$page', method: HttpMethods.GET),
    fromJson: (json) => ModelFAQ.fromJson(json),
  );
}

Future<PayoutRecord> getDriverPayout({
  required int page,
  required int driverId,
  required String? status,
}) async {
  return parseModel(
    apiCall: executeRequest('driver-payout-document-list?driver_id=$driverId&page=$page&status=$status', method: HttpMethods.GET),
    fromJson: (json) => PayoutRecord.fromJson(json),
  );
}

Future<PolyLineData> getPolylineData(String origins, String destinations) async {
  return parseModel(
    apiCall: executeRequest('directions-polyline-api?origin=$origins&destination=$destinations', method: HttpMethods.GET),
    fromJson: (json) => PolyLineData.fromJson(json),
  );
}

Future<ReviewsModel> getReviewList({required int page}) async {
  return parseModel(
    apiCall: executeRequest('driver-rating-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => ReviewsModel.fromJson(json),
  );
}
