import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:mighty_core/utils/core_enum.dart';
import 'package:mighty_core/utils/core_network_utils.dart';
import 'package:taxi_booking/model/PolyLineData.dart';
import 'package:taxi_booking/model/ReviewsModel.dart';
import 'package:taxi_booking/model/search_location_model.dart';
import 'package:taxi_booking/model/select_location_model.dart';

import '../manage_imports.dart';

Future<LoginResponse> signUpApi(Map request) async {
  return parseModel(
    apiCall: executeRequest('register', method: HttpMethods.POST, request: request),
    fromJson: (json) => LoginResponse.fromJson(json),
  ).then((loginResponse) async {
    if (loginResponse.data!.loginType == 'mobile') {
      await sharedPref.setString(TOKEN, loginResponse.data!.apiToken.validate());
      await sharedPref.setString(USER_TYPE, loginResponse.data!.userType.validate());
      await sharedPref.setString(FIRST_NAME, loginResponse.data!.firstName.validate());
      await sharedPref.setString(LAST_NAME, loginResponse.data!.lastName.validate());
      await sharedPref.setString(CONTACT_NUMBER, loginResponse.data!.contactNumber.validate());
      await sharedPref.setString(USER_EMAIL, loginResponse.data!.email.validate());
      await sharedPref.setString(USER_NAME, loginResponse.data!.username.validate());
      await sharedPref.setString(ADDRESS, loginResponse.data!.address.validate());
      await sharedPref.setInt(USER_ID, loginResponse.data!.id!);
      await sharedPref.setString(USER_PROFILE_PHOTO, loginResponse.data!.profileImage.validate());
      await sharedPref.setString(GENDER, loginResponse.data!.gender.validate());
      await sharedPref.setString(LOGIN_TYPE, loginResponse.data!.loginType.validate());
      await appStore.setLoggedIn(true);
      await appStore.setUserEmail(loginResponse.data!.email.validate());
      await sharedPref.setString(UID, loginResponse.data!.uid.validate());
      await appStore.setUserProfile(loginResponse.data!.profileImage.validate());
      await appStore.setReferralCode(loginResponse.data!.referralCode.validate());
      MightyCore().configure(authToken: loginResponse.data!.apiToken.validate());
    }
    return loginResponse;
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
      await sharedPref.setString(USER_PROFILE_PHOTO, loginResponse.data!.profileImage.validate());
      await sharedPref.setString(GENDER, loginResponse.data!.gender.validate());
      await sharedPref.setString(LOGIN_TYPE, loginResponse.data!.loginType.validate());
      await appStore.setLoggedIn(true);
      await appStore.setUserEmail(loginResponse.data!.email.validate());
      if (loginResponse.data!.uid != null) await sharedPref.setString(UID, loginResponse.data!.uid.validate());
      await appStore.setUserProfile(loginResponse.data!.profileImage.validate());
      await appStore.setReferralCode(loginResponse.data!.referralCode.validate());
      MightyCore().configure(authToken: loginResponse.data!.apiToken.validate());
    }
    return loginResponse;
  }).catchError((e) {
    log('${e.toString()}');
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
//   await multiPartRequest.send().then((res) {
//     res.stream.bytesToString().then(
//       (value) {
//         onSuccess?.call(jsonDecode(value));
//       },
//     );
//   }).catchError((error) {
//     onError?.call(error.toString());
//   });
// }

/// Profile Update
Future updateProfile({String? uid, String? firstName, String? lastName, String? userEmail, String? contactNumber, File? file}) async {
  Map<String, File> files = {};
  if (file != null) files['profile_image'] = file;

  return parseModel(
    apiCall: executeRequest(
      'update-profile',
      method: HttpMethods.POST,
      fields: {
        'id': sharedPref.getInt(USER_ID).toString(),
        'username': sharedPref.getString(USER_NAME).validate(),
        'email': userEmail ?? appStore.userEmail,
        'first_name': firstName.validate(),
        'last_name': lastName.validate(),
        'contact_number': contactNumber.validate(),
        'uid': uid.validate(),
        'player_id': sharedPref.getString(PLAYER_ID).toString(),
      },
      files: files,
    ),
    fromJson: (json) => LoginResponse.fromJson(json),
  ).then((res) async {
    if (res.data != null) {
      await sharedPref.setString(FIRST_NAME, res.data!.firstName.validate());
      await sharedPref.setString(LAST_NAME, res.data!.lastName.validate());
      await sharedPref.setString(USER_PROFILE_PHOTO, res.data!.profileImage.validate());
      await sharedPref.setString(USER_NAME, res.data!.username.validate());
      await sharedPref.setString(USER_ADDRESS, res.data!.address.validate());
      await sharedPref.setString(CONTACT_NUMBER, res.data!.contactNumber.validate());
      await sharedPref.setString(GENDER, res.data!.gender.validate());
      await appStore.setUserEmail(res.data!.email.validate());
      await appStore.setUserProfile(res.data!.profileImage.validate());
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

Future<LoginResponse> getUserDetail({int? userId}) async {
  return parseModel(
    apiCall: executeRequest('user-detail?id=$userId', method: HttpMethods.GET),
    fromJson: (json) => LoginResponse.fromJson(json),
  );
}

Future<WalletListModel> getWalletList({required int page}) async {
  return parseModel(
    apiCall: executeRequest('wallet-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => WalletListModel.fromJson(json),
  );
}

/// The rider's own bank account number for wallet top-ups by transfer.
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

Future<LDBaseResponse> saveCoinWallet(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-coin-wallet', method: HttpMethods.POST, request: request),
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

Future<EstimatePriceModel> estimatePriceList(Map request) async {
  return parseModel(
    apiCall: executeRequest('estimate-price-time', method: HttpMethods.POST, request: request),
    fromJson: (json) => EstimatePriceModel.fromJson(json),
  );
}

Future<CouponListModel> getCouponList({required int page, required int serviceId}) async {
  return parseModel(
    apiCall: executeRequest('coupon-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => CouponListModel.fromJson(json),
  );
}

Future<ModelZoneList> getZoneList({String? name, int? zoneId}) async {
  return parseModel(
    apiCall: executeRequest('managezone-list?per_page=1000&name=$name&zone_id=$zoneId', method: HttpMethods.GET),
    fromJson: (json) => ModelZoneList.fromJson(json),
  );
}

Future<ModelAirportList> getAirportList({String? name}) async {
  return parseModel(
    apiCall: executeRequest('airport-list?per_page=1000&name=$name', method: HttpMethods.GET),
    fromJson: (json) => ModelAirportList.fromJson(json),
  );
}

Future<LDBaseResponse> savePayment(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-payment', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> saveRideRequest(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-riderequest', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<BidListingModel> getBidListing(Map request) async {
  return parseModel(
    apiCall: executeRequest('get-bidding-riderequest', method: HttpMethods.POST, request: request),
    fromJson: (json) => BidListingModel.fromJson(json),
  );
}

Future<LDBaseResponse> responseBidListing(Map request) async {
  return parseModel(
    apiCall: executeRequest('riderequest-bid-respond', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<AppSettingModel> getAppSetting() async {
  return parseModel(
    apiCall: executeRequest('admin-dashboard', method: HttpMethods.GET),
    fromJson: (json) => AppSettingModel.fromJson(json),
  );
}

Future<CurrentRequestModel> getCurrentRideRequest() async {
  return parseModel(
    apiCall: executeRequest('current-riderequest', method: HttpMethods.GET),
    fromJson: (json) {
      if (json is List) {
        if (json.isEmpty) {
          return CurrentRequestModel(
            rideRequest: null,
            onRideRequest: null,
            schedule_ride_request: [],
          );
        } else {
          return CurrentRequestModel.fromJson(json[0]);
        }
      } else {
        return CurrentRequestModel.fromJson(json);
      }
    },
  );
}

Future<LDBaseResponse> rideRequestUpdate({required Map request, int? rideId}) async {
  return parseModel(
    apiCall: executeRequest('riderequest-update/$rideId', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<ServerLanguageResponse> getLanguageList(versionNo) async {
  return parseModel(
    apiCall: executeRequest('language-table-list?version_no=$versionNo', method: HttpMethods.GET),
    fromJson: (json) => ServerLanguageResponse.fromJson(json),
  );
}

Future<LDBaseResponse> ratingReview({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('save-ride-rating', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<LDBaseResponse> adminNotify({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('admin-sos-notify', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<RiderListModel> getRiderRequestList({int? page, String? status, LatLng? sourceLatLog, int? riderId}) async {
  return parseModel(
    apiCall: executeRequest(
      sourceLatLog != null
          ? 'riderequest-list?page=$page&rider_id=$riderId'
          : status != null
              ? 'riderequest-list?page=$page&status=$status&rider_id=$riderId'
              : 'riderequest-list?page=$page&rider_id=$riderId',
      method: HttpMethods.GET,
    ),
    fromJson: (json) => RiderListModel.fromJson(json),
  );
}

Future<LDBaseResponse> saveComplain({required Map request}) async {
  return parseModel(
    apiCall: executeRequest('save-complaint', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<RideDetailModel> rideDetail({required int? orderId}) async {
  return parseModel(
    apiCall: executeRequest('riderequest-detail?id=$orderId', method: HttpMethods.GET),
    fromJson: (json) => RideDetailModel.fromJson(json),
  );
}

Future<NotificationListModel> getNotification({required int page}) async {
  return parseModel(
    apiCall: executeRequest('notification-list?page=$page&limit=$PER_PAGE', method: HttpMethods.POST),
    fromJson: (json) => NotificationListModel.fromJson(json),
  );
}

Future<LoginResponse> updateStatus(Map request) async {
  return parseModel(
    apiCall: executeRequest('update-user-status', method: HttpMethods.POST, request: request),
    fromJson: (json) => LoginResponse.fromJson(json),
  );
}

Future<LDBaseResponse> deleteUser() async {
  return parseModel(
    apiCall: executeRequest('delete-user-account', method: HttpMethods.POST),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

/// Profile Update
Future updateProfileUid() async {
  return parseModel(
    apiCall: executeRequest(
      'update-profile',
      method: HttpMethods.POST,
      fields: {
        'id': sharedPref.getInt(USER_ID).toString(),
        'username': sharedPref.getString(USER_NAME).validate(),
        'email': sharedPref.getString(USER_EMAIL).validate(),
        'uid': sharedPref.getString(UID).toString(),
      },
    ),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  ).catchError((error) {
    toast(error.toString());
  });
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

Future<UserDetailModel> getDriverDetail({int? userId}) async {
  return parseModel(
    apiCall: executeRequest('user-detail?id=$userId', method: HttpMethods.GET),
    fromJson: (json) => UserDetailModel.fromJson(json),
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
  sharedPref.remove(COUNTRY);
  appStore.setLoggedIn(false);
  if (!(sharedPref.getBool(REMEMBER_ME) ?? false) || sharedPref.getString(LOGIN_TYPE) == LoginTypeGoogle || sharedPref.getString(LOGIN_TYPE) == 'mobile') {
    sharedPref.remove(USER_EMAIL);
    sharedPref.remove(USER_PASSWORD);
    sharedPref.remove(REMEMBER_ME);
  }
  sharedPref.remove(LOGIN_TYPE);
  launchScreen(getContext, SignInScreen(), isNewTask: true);
}

Future<NearByDriverModel> getNearByDriverList({LatLng? latLng}) async {
  return parseModel(
    apiCall: executeRequest('near-by-driver?latitude=${latLng!.latitude}&longitude=${latLng.longitude}', method: HttpMethods.GET),
    fromJson: (json) => NearByDriverModel.fromJson(json),
  );
}

Future<WalletInfoModel> getWalletData() async {
  return parseModel(
    apiCall: executeRequest('wallet-detail', method: HttpMethods.GET),
    fromJson: (json) => WalletInfoModel.fromJson(json),
  );
}

Future<WithDrawListModel> getWithDrawList({int? page}) async {
  return parseModel(
    apiCall: executeRequest('withdrawrequest-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => WithDrawListModel.fromJson(json),
  );
}

Future<RewardsListModel> getRewardsList({int? page}) async {
  return parseModel(
    apiCall: executeRequest('reward-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => RewardsListModel.fromJson(json),
  );
}

Future<CoinWalletListModel> getCoinWalletList({required int page}) async {
  return parseModel(
    apiCall: executeRequest('coin-wallet-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => CoinWalletListModel.fromJson(json),
  );
}

Future<LDBaseResponse> saveWithDrawRequest(Map request) async {
  return parseModel(
    apiCall: executeRequest('save-withdrawrequest', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<ReferralHistoryListModel> getReferralList({int? page}) async {
  return parseModel(
    apiCall: executeRequest('reference-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => ReferralHistoryListModel.fromJson(json),
  );
}

Future<ModelFAQ> getFaqList({required int page}) async {
  return parseModel(
    apiCall: executeRequest('faq-list?app=rider&page=$page', method: HttpMethods.GET),
    fromJson: (json) => ModelFAQ.fromJson(json),
  );
}

Future<cancelReasonList> getCancelReasonList({required String type}) async {
  return parseModel(
    apiCall: executeRequest('cancelReason-list?type=$type', method: HttpMethods.GET),
    fromJson: (json) => cancelReasonList.fromJson(json),
  );
}

/// Update Bank Info
Future updateBankDetail({String? bankName, String? bankCode, String? accountName, String? accountNumber, String? routing, String? iban, String? swift}) async {
  return parseModel(
    apiCall: executeRequest(
      'update-profile',
      method: HttpMethods.POST,
      fields: {
        'email': sharedPref.getString(USER_EMAIL).validate(),
        'contact_number': sharedPref.getString(CONTACT_NUMBER).validate(),
        'username': sharedPref.getString(USER_NAME).validate(),
        'user_bank_account[bank_name]': bankName.validate(),
        'user_bank_account[bank_code]': bankCode.validate(),
        'user_bank_account[account_holder_name]': accountName.validate(),
        'user_bank_account[account_number]': accountNumber.validate(),
        'user_bank_account[routing_number]': routing.validate(),
        'user_bank_account[bank_iban]': iban.validate(),
        'user_bank_account[bank_swift]': swift.validate(),
      },
    ),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  ).catchError((error) {
    toast(error.toString());
  });
}

Future<LDBaseResponse> updateExtraChargePaymentMethod(Map request) async {
  return parseModel(
    apiCall: executeRequest('update-extra-charge-paymentmethod', method: HttpMethods.POST, request: request),
    fromJson: (json) => LDBaseResponse.fromJson(json),
  );
}

Future<PolyLineData> getPolylineData(String origins, String destinations) async {
  return parseModel(
    apiCall: executeRequest('directions-polyline-api?origin=$origins&destination=$destinations', method: HttpMethods.GET),
    fromJson: (json) => PolyLineData.fromJson(json),
  );
}

Future<SearchLocationModel> searchAddressRequest(Map request) async {
  return parseModel(
    apiCall: executeRequest('place-autocomplete-api', method: HttpMethods.POST, request: request),
    fromJson: (json) => SearchLocationModel.fromJson(json),
  );
}

Future<SelectLocationModel> searchAddressRequestPlaceId(String placeId) async {
  return parseModel(
    apiCall: executeRequest('place-detail-api?placeid=$placeId', method: HttpMethods.GET),
    fromJson: (json) => SelectLocationModel.fromJson(json),
  );
}

Future<ReviewsModel> getReviewList({required int page}) async {
  return parseModel(
    apiCall: executeRequest('rider-rating-list?page=$page', method: HttpMethods.GET),
    fromJson: (json) => ReviewsModel.fromJson(json),
  );
}
