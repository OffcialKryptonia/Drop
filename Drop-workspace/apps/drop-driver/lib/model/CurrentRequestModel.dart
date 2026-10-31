import 'package:taxi_driver/model/CouponData.dart';
import 'package:taxi_driver/model/ExtraChargeRequestModel.dart';
import 'package:taxi_driver/model/RideHistory.dart';
import 'package:taxi_driver/model/UserDetailModel.dart';

import 'RiderModel.dart';

class CurrentRequestModel {
  int? id;
  String? displayName;
  String? email;
  String? username;
  String? userType;
  String? profileImage;
  String? status;
  String? latitude;
  String? longitude;
  String? service_marker;
  int? ride_has_bids;
  OnRideRequest? rideRequest;
  OnRideRequest? onRideRequest;
  List<OnRideRequest>? schedule_ride_request;
  List<OnRideRequest>? schedule_orders;
  UserData? rider;
  Payment? payment;
  var estimated_price;
  var driver_distance_to_pickup;
  var driver_duration_to_pickup;
  var all_unread_count;

  CurrentRequestModel({
    this.id,
    this.displayName,
    this.email,
    this.username,
    this.userType,
    this.profileImage,
    this.status,
    this.latitude,
    this.longitude,
    this.onRideRequest,
    this.rider,
    this.payment,
    this.service_marker,
    this.ride_has_bids,
    this.schedule_ride_request,
    this.schedule_orders,
    this.rideRequest,
    this.estimated_price,
    this.driver_distance_to_pickup,
    this.driver_duration_to_pickup,
    this.all_unread_count,
  });

  CurrentRequestModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    estimated_price = json['estimated_price'];
    driver_distance_to_pickup = json['driver_distance_to_pickup'];
    driver_duration_to_pickup = json['driver_duration_to_pickup'];
    all_unread_count = int.tryParse(json['all_unread_count'].toString()) ?? 0;
    service_marker = json['service_marker'];
    displayName = json['display_name'];
    email = json['email'];
    ride_has_bids = json['ride_has_bid'];
    username = json['username'];
    userType = json['user_type'];
    profileImage = json['profile_image'];
    status = json['status'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    rideRequest = json['ride_request'] != null ? new OnRideRequest.fromJson(json['ride_request']) : null;
    onRideRequest = json['on_ride_request'] != null ? new OnRideRequest.fromJson(json['on_ride_request']) : null;
    rider = json['rider'] != null ? new UserData.fromJson(json['rider']) : null;
    payment = json['payment'] != null ? new Payment.fromJson(json['payment']) : null;
    schedule_ride_request = json['schedule_ride_request'] != null ? (json['schedule_ride_request'] as List).map((item) => OnRideRequest.fromJson(item)).toList() : [];
    schedule_orders = json['schedule_orders'] != null ? (json['schedule_orders'] as List).map((item) => OnRideRequest.fromJson(item)).toList() : [];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['estimated_price'] = this.estimated_price;
    data['driver_distance_to_pickup'] = this.driver_distance_to_pickup;
    data['driver_duration_to_pickup'] = this.driver_duration_to_pickup;
    data['all_unread_count'] = this.all_unread_count;
    data['display_name'] = this.displayName;
    data['service_marker'] = this.service_marker;
    data['email'] = this.email;
    data['ride_has_bid'] = this.ride_has_bids;
    data['username'] = this.username;
    data['user_type'] = this.userType;
    data['profile_image'] = this.profileImage;
    data['status'] = this.status;
    data['latitude'] = this.latitude;
    data['longitude'] = this.longitude;
    if (this.rideRequest != null) {
      data['ride_request'] = this.rideRequest!.toJson();
    }
    if (this.onRideRequest != null) {
      data['on_ride_request'] = this.onRideRequest!.toJson();
    }
    if (this.rider != null) {
      data['rider'] = this.rider!.toJson();
    }
    if (this.payment != null) {
      data['payment'] = this.payment!.toJson();
    }
    if (this.schedule_ride_request != null && this.schedule_ride_request!.isNotEmpty) {
      data['schedule_ride_request'] = schedule_ride_request!.isNotEmpty ? schedule_ride_request!.map((item) => item.toJson()).toList() : [];
    }
    if (this.schedule_orders != null && this.schedule_orders!.isNotEmpty) {
      data['schedule_orders'] = schedule_orders!.isNotEmpty ? schedule_orders!.map((item) => item.toJson()).toList() : [];
    }
    return data;
  }
}

class OnRideRequest {
  int? id;
  int? riderId;
  int? passenger;
  int? luggage;
  int? serviceId;
  String? datetime;
  String? schedule_datetime;
  num? extraChargeAmount;
  int? isSchedule;
  int? rideAttempt;
  String? otp;
  num? totalAmount;
  num? adminCommission;
  String? commissionType;
  num? adminEarning;
  num? dropoff_distance_in_km;
  num? subtotal;
  num? extraChargesAmount;
  int? driverId;
  String? driverName;
  String? riderName;
  String? driverProfileImage;
  String? riderProfileImage;
  String? startLatitude;
  String? startLongitude;
  String? startAddress;
  String? endLatitude;
  String? endLongitude;
  String? endAddress;
  String? distanceUnit;
  String? startTime;
  String? endTime;
  num? distance;
  num? duration;
  num? seatCount;
  String? reason;
  String? status;
  num? baseFare;
  num? minimumFare;
  num? perDistance;
  num? perMinuteDrive;
  num? perMinuteWaiting;
  num? waitingTime;
  num? waitingTimeLimit;
  num? waitingTimeCharges;
  num? cancelationCharges;
  String? cancelBy;
  num? paymentId;
  String? paymentType;
  String? paymentStatus;
  List<ExtraChargeRequestModel>? extraCharges;
  num? couponDiscount;
  var couponCode;
  CouponData? couponData;
  num? isRiderRated;
  num? isDriverRated;
  num? maxTimeForFindDriverForRideRequest;
  String? createdAt;
  String? updatedAt;
  String? driverContactNumber;
  String? riderContactNumber;
  String? driverEmail;
  String? riderEmail;
  int? regionId;
  int? isRideForOther;
  OtherRiderData? otherRiderData;
  List<MultiDropLocation>? multiDropLocation;

  String? type;
  int? weight;
  String? parcelDescription;
  String? pickupContactNumber;
  String? pickupPersonName;
  String? pickupDescription;
  String? deliveryContactNumber;
  String? deliveryPersonName;
  String? deliveryDescription;

  String? flight_number;
  String? pickup_point;
  String? preferred_pickup_time;
  String? preferred_dropoff_time;
  String? trip_type;
  List<RideHistory>? rideHistory;

  OnRideRequest({
    this.passenger,
    this.luggage,
    this.rideHistory,
    this.flight_number,
    this.pickup_point,
    this.preferred_pickup_time,
    this.preferred_dropoff_time,
    this.trip_type,
    this.schedule_datetime,
    this.extraChargeAmount,
    this.type,
    this.weight,
    this.parcelDescription,
    this.pickupContactNumber,
    this.pickupPersonName,
    this.pickupDescription,
    this.deliveryContactNumber,
    this.deliveryPersonName,
    this.deliveryDescription,
    this.id,
    this.riderId,
    this.serviceId,
    this.multiDropLocation,
    this.datetime,
    this.isSchedule,
    this.rideAttempt,
    this.otp,
    this.totalAmount,
    this.adminCommission,
    this.commissionType,
    this.adminEarning,
    this.dropoff_distance_in_km,
    this.subtotal,
    this.extraChargesAmount,
    this.driverId,
    this.driverName,
    this.riderName,
    this.driverProfileImage,
    this.riderProfileImage,
    this.startLatitude,
    this.startLongitude,
    this.startAddress,
    this.endLatitude,
    this.endLongitude,
    this.endAddress,
    this.distanceUnit,
    this.startTime,
    this.endTime,
    this.distance,
    this.duration,
    this.seatCount,
    this.reason,
    this.status,
    this.baseFare,
    this.minimumFare,
    this.perDistance,
    this.perMinuteDrive,
    this.perMinuteWaiting,
    this.waitingTime,
    this.waitingTimeLimit,
    this.waitingTimeCharges,
    this.cancelationCharges,
    this.cancelBy,
    this.paymentId,
    this.paymentType,
    this.paymentStatus,
    this.extraCharges,
    this.couponDiscount,
    this.couponCode,
    this.couponData,
    this.isRiderRated,
    this.isDriverRated,
    this.maxTimeForFindDriverForRideRequest,
    this.createdAt,
    this.updatedAt,
    this.driverContactNumber,
    this.riderContactNumber,
    this.driverEmail,
    this.riderEmail,
    this.regionId,
    this.otherRiderData,
    this.isRideForOther,
  });

  OnRideRequest.fromJson(Map<String, dynamic> json) {
    rideHistory = json['ride_history'] != null ? (json['ride_history'] as List).map((i) => RideHistory.fromJson(i)).toList() : null;
    luggage = json['luggage'];
    passenger = json['passenger'];
    type = json['type'];
    weight = json['weight'];
    parcelDescription = json['parcel_description'];
    pickupContactNumber = json['pickup_contact_number'];
    pickupPersonName = json['pickup_person_name'];
    pickupDescription = json['pickup_description'];
    deliveryContactNumber = json['delivery_contact_number'];
    deliveryPersonName = json['delivery_person_name'];
    deliveryDescription = json['delivery_description'];
    schedule_datetime = json['schedule_datetime'];
    extraChargeAmount = json['extraChargeAmount'];
    trip_type = json['trip_type'];
    flight_number = json['flight_number'];
    pickup_point = json['pickup_point'];
    preferred_pickup_time = json['preferred_pickup_time'];
    preferred_dropoff_time = json['preferred_dropoff_time'];
    id = json['id'];
    riderId = json['rider_id'];
    serviceId = json['service_id'];
    datetime = json['datetime'];
    isSchedule = json['is_schedule'];
    rideAttempt = json['ride_attempt'];
    otp = json['otp'];
    totalAmount = num.tryParse(json['total_amount'].toString());
    adminCommission = num.tryParse(json['admin_commission'].toString()) ?? 0;
    adminEarning = num.tryParse(json['admin_earning'].toString());

    // ✅ FIXED: Keep as-is from backend. Ride distance assigned in getNewRideReq
    dropoff_distance_in_km = num.tryParse(json['dropoff_distance_in_km'].toString());

    subtotal = num.tryParse(json['subtotal'].toString());
    extraChargesAmount = json['extra_charges_amount'];
    driverId = json['driver_id'];
    driverName = json['driver_name'];
    riderName = json['rider_name'];
    commissionType = json['commission_type'];
    driverProfileImage = json['driver_profile_image'];
    riderProfileImage = json['rider_profile_image'];
    startLatitude = json['start_latitude'];
    startLongitude = json['start_longitude'];
    startAddress = json['start_address'];
    endLatitude = json['end_latitude'];
    endLongitude = json['end_longitude'];
    endAddress = json['end_address'];
    multiDropLocation = json["multi_drop_location"] == null ? [] : List<MultiDropLocation>.from(json["multi_drop_location"]!.map((x) => MultiDropLocation.fromJson(x)));
    distanceUnit = json['distance_unit'];
    startTime = json['start_time'];
    endTime = json['end_time'];
    distance = json['distance'];
    duration = json['duration'];
    seatCount = json['seat_count'];
    reason = json['reason'];
    status = json['status'];
    baseFare = json['base_fare'];
    minimumFare = json['minimum_fare'];
    perDistance = json['per_distance'];
    perMinuteDrive = json['per_minute_drive'];
    perMinuteWaiting = json['per_minute_waiting'];
    waitingTime = json['waiting_time'];
    waitingTimeLimit = json['waiting_time_limit'];
    waitingTimeCharges = json['waiting_time_charges'];
    cancelationCharges = json['cancelation_charges'];
    cancelBy = json['cancel_by'];
    paymentId = json['payment_id'];
    paymentType = json['payment_type'];
    paymentStatus = json['payment_status'];
    if (json['extra_charges'] != null) {
      extraCharges = <ExtraChargeRequestModel>[];
      json['extra_charges'].forEach((v) {
        extraCharges!.add(new ExtraChargeRequestModel.fromJson(v));
      });
    }
    couponDiscount = json['coupon_discount'];
    couponData = json['coupon_data'] != null ? CouponData.fromJson(json['coupon_data']) : null;
    isRiderRated = json['is_rider_rated'];
    isDriverRated = json['is_driver_rated'];
    maxTimeForFindDriverForRideRequest = json['max_time_for_find_driver_for_ride_request'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    driverContactNumber = json['driver_contact_number'];
    riderContactNumber = json['rider_contact_number'];
    riderEmail = json['rider_email'];
    driverEmail = json['driver_email'];
    regionId = json['region_id'];
    otherRiderData = json['other_rider_data'] != null ? new OtherRiderData.fromJson(json['other_rider_data']) : null;
    isRideForOther = json['is_ride_for_other'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.rideHistory != null) {
      data['ride_history'] = this.rideHistory!.map((v) => v.toJson()).toList();
    }
    data['trip_type'] = this.trip_type;
    data['flight_number'] = this.flight_number;
    data['pickup_point'] = this.pickup_point;
    data['preferred_pickup_time'] = this.preferred_pickup_time;
    data['preferred_dropoff_time'] = this.preferred_dropoff_time;
    data['schedule_datetime'] = this.schedule_datetime;
    data['extraChargeAmount'] = this.extraChargeAmount;
    data['type'] = this.type;
    data['weight'] = weight;
    data['parcel_description'] = parcelDescription;
    data['pickup_contact_number'] = pickupContactNumber;
    data['pickup_person_name'] = pickupPersonName;
    data['pickup_description'] = pickupDescription;
    data['delivery_contact_number'] = deliveryContactNumber;
    data['delivery_person_name'] = deliveryPersonName;
    data['delivery_description'] = deliveryDescription;
    data['id'] = this.id;
    data['rider_id'] = this.riderId;
    data['service_id'] = this.serviceId;
    data['datetime'] = this.datetime;
    data['is_schedule'] = this.isSchedule;
    data['ride_attempt'] = this.rideAttempt;
    data['otp'] = this.otp;
    data['total_amount'] = this.totalAmount;
    data['admin_commission'] = this.adminCommission;
    data['commission_type'] = this.commissionType;
    data['admin_earning'] = this.adminEarning;
    data['dropoff_distance_in_km'] = this.dropoff_distance_in_km;
    data['subtotal'] = this.subtotal;
    data['extra_charges_amount'] = this.extraChargesAmount;
    data['driver_id'] = this.driverId;
    data['driver_name'] = this.driverName;
    data['rider_name'] = this.riderName;
    data['driver_profile_image'] = this.driverProfileImage;
    data['rider_profile_image'] = this.riderProfileImage;
    data['start_latitude'] = this.startLatitude;
    data['start_longitude'] = this.startLongitude;
    data['start_address'] = this.startAddress;
    data['end_latitude'] = this.endLatitude;
    data['end_longitude'] = this.endLongitude;
    data['end_address'] = this.endAddress;
    data['distance_unit'] = this.distanceUnit;
    data['start_time'] = this.startTime;
    data['end_time'] = this.endTime;
    data['distance'] = this.distance;
    data['duration'] = this.duration;
    data['seat_count'] = this.seatCount;
    data['reason'] = this.reason;
    data['status'] = this.status;
    data['base_fare'] = this.baseFare;
    data['minimum_fare'] = this.minimumFare;
    data['per_distance'] = this.perDistance;
    data['per_minute_drive'] = this.perMinuteDrive;
    data['per_minute_waiting'] = this.perMinuteWaiting;
    data['waiting_time'] = this.waitingTime;
    data['waiting_time_limit'] = this.waitingTimeLimit;
    data['waiting_time_charges'] = this.waitingTimeCharges;
    data['cancelation_charges'] = this.cancelationCharges;
    data['cancel_by'] = this.cancelBy;
    data['payment_id'] = this.paymentId;
    data['payment_type'] = this.paymentType;
    data['payment_status'] = this.paymentStatus;
    if (this.extraCharges != null) {
      data['extra_charges'] = this.extraCharges!.map((v) => v.toJson()).toList();
    }
    if (multiDropLocation != null) {
      data["multi_drop_location"] = List<dynamic>.from(multiDropLocation!.map((x) => x.toJson()));
    }
    data['coupon_discount'] = this.couponDiscount;
    data['coupon_code'] = this.couponCode;
    data['coupon_data'] = this.couponData;
    data['is_rider_rated'] = this.isRiderRated;
    data['is_driver_rated'] = this.isDriverRated;
    data['max_time_for_find_driver_for_ride_request'] = this.maxTimeForFindDriverForRideRequest;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    if (this.couponData != null) {
      data['coupon_data'] = this.couponData!.toJson();
    }
    data['rider_contact_number'] = this.riderContactNumber;
    data['driver_contact_number'] = this.driverContactNumber;
    data['driver_email'] = this.driverEmail;
    data['rider_email'] = this.riderEmail;
    data['regionId'] = this.regionId;
    data['is_ride_for_other'] = this.isRideForOther;
    if (this.otherRiderData != null) {
      data['other_rider_data'] = this.otherRiderData!.toJson();
    }
    return data;
  }
}

class EstimatedPriceModel {
  int? id;
  int? serviceId;
  String? name;
  int? regionId;
  String? distanceUnit;
  num? dropoffDistanceInKm;
  num? duration;
  int? capacity;
  num? baseFare;
  num? minimumFare;
  num? minimumDistance;
  num? perDistance;
  num? perMinuteDrive;
  num? perMinuteWait;
  num? waitingTimeLimit;
  num? cancellationFee;
  String? paymentMethod;
  String? serviceImage;
  String? serviceMarker;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? description;
  String? commissionType;
  num? adminCommission;
  num? fleetCommission;
  Map<String, dynamic>? couponDiscount;
  num? distance;
  num? minimumDistanceInKm;
  num? distancePrice;
  num? timePrice;
  num? totalAmount;
  num? subtotal;
  num? discountAmount;
  num? fixedCharge;

  EstimatedPriceModel({
    this.id,
    this.serviceId,
    this.name,
    this.regionId,
    this.distanceUnit,
    this.dropoffDistanceInKm,
    this.duration,
    this.capacity,
    this.baseFare,
    this.minimumFare,
    this.minimumDistance,
    this.perDistance,
    this.perMinuteDrive,
    this.perMinuteWait,
    this.waitingTimeLimit,
    this.cancellationFee,
    this.paymentMethod,
    this.serviceImage,
    this.serviceMarker,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.description,
    this.commissionType,
    this.adminCommission,
    this.fleetCommission,
    this.couponDiscount,
    this.distance,
    this.minimumDistanceInKm,
    this.distancePrice,
    this.timePrice,
    this.totalAmount,
    this.subtotal,
    this.discountAmount,
    this.fixedCharge,
  });

  factory EstimatedPriceModel.fromJson(Map<String, dynamic> json) {
    return EstimatedPriceModel(
      id: json['id'],
      serviceId: json['service_id'],
      name: json['name'],
      regionId: json['region_id'],
      distanceUnit: json['distance_unit'],
      dropoffDistanceInKm: json['dropoff_distance_in_km'],
      duration: json['duration'],
      capacity: json['capacity'],
      baseFare: json['base_fare'],
      minimumFare: json['minimum_fare'],
      minimumDistance: json['minimum_distance'],
      perDistance: json['per_distance'],
      perMinuteDrive: json['per_minute_drive'],
      perMinuteWait: json['per_minute_wait'],
      waitingTimeLimit: json['waiting_time_limit'],
      cancellationFee: json['cancellation_fee'],
      paymentMethod: json['payment_method'],
      serviceImage: json['service_image'],
      serviceMarker: json['service_marker'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      description: json['description'],
      commissionType: json['commission_type'],
      adminCommission: json['admin_commission'],
      fleetCommission: json['fleet_commission'],
      couponDiscount: json['coupon_discount'] ?? {},
      distance: json['distance'],
      minimumDistanceInKm: json['minimum_distance_in_km'],
      distancePrice: json['distance_price'],
      timePrice: json['time_price'],
      totalAmount: json['total_amount'],
      subtotal: json['subtotal'],
      discountAmount: json['discount_amount'],
      fixedCharge: json['fixed_charge'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_id': serviceId,
      'name': name,
      'region_id': regionId,
      'distance_unit': distanceUnit,
      'dropoff_distance_in_km': dropoffDistanceInKm,
      'duration': duration,
      'capacity': capacity,
      'base_fare': baseFare,
      'minimum_fare': minimumFare,
      'minimum_distance': minimumDistance,
      'per_distance': perDistance,
      'per_minute_drive': perMinuteDrive,
      'per_minute_wait': perMinuteWait,
      'waiting_time_limit': waitingTimeLimit,
      'cancellation_fee': cancellationFee,
      'payment_method': paymentMethod,
      'service_image': serviceImage,
      'service_marker': serviceMarker,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'description': description,
      'commission_type': commissionType,
      'admin_commission': adminCommission,
      'fleet_commission': fleetCommission,
      'coupon_discount': couponDiscount,
      'distance': distance,
      'minimum_distance_in_km': minimumDistanceInKm,
      'distance_price': distancePrice,
      'time_price': timePrice,
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'fixed_charge': fixedCharge,
    };
  }
}

class Payment {
  int? id;
  int? rideRequestId;
  int? riderId;
  String? riderName;
  String? datetime;
  num? totalAmount;
  var receivedBy;
  num? adminCommission;
  int? fleetCommission;
  num? driverFee;
  num? driverTips;
  num? driverCommission;
  var txnId;
  String? paymentType;
  String? paymentStatus;
  var transactionDetail;
  String? createdAt;
  String? updatedAt;

  Payment({
    this.id,
    this.rideRequestId,
    this.riderId,
    this.riderName,
    this.datetime,
    this.totalAmount,
    this.receivedBy,
    this.adminCommission,
    this.fleetCommission,
    this.driverFee,
    this.driverTips,
    this.driverCommission,
    this.txnId,
    this.paymentType,
    this.paymentStatus,
    this.transactionDetail,
    this.createdAt,
    this.updatedAt,
  });

  Payment.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    rideRequestId = json['ride_request_id'];
    riderId = json['rider_id'];
    riderName = json['rider_name'];
    datetime = json['datetime'];
    totalAmount = json['total_amount'];
    receivedBy = json['received_by'];
    adminCommission = json['admin_commission'];
    fleetCommission = json['fleet_commission'];
    driverFee = json['driver_fee'];
    driverTips = json['driver_tips'];
    driverCommission = json['driver_commission'];
    txnId = json['txn_id'];
    paymentType = json['payment_type'];
    paymentStatus = json['payment_status'];
    transactionDetail = json['transaction_detail'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['ride_request_id'] = this.rideRequestId;
    data['rider_id'] = this.riderId;
    data['rider_name'] = this.riderName;
    data['datetime'] = this.datetime;
    data['total_amount'] = this.totalAmount;
    data['received_by'] = this.receivedBy;
    data['admin_commission'] = this.adminCommission;
    data['fleet_commission'] = this.fleetCommission;
    data['driver_fee'] = this.driverFee;
    data['driver_tips'] = this.driverTips;
    data['driver_commission'] = this.driverCommission;
    data['txn_id'] = this.txnId;
    data['payment_type'] = this.paymentType;
    data['payment_status'] = this.paymentStatus;
    data['transaction_detail'] = this.transactionDetail;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}