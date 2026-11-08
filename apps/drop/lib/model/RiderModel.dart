import '../manage_imports.dart';

class RiderModel {
  int? id;
  int? riderId;
  int? ride_has_bids;
  int? serviceId;
  String? datetime;
  int? isSchedule;
  int? rideAttempt;
  String? otp;
  var adminCommission;
  var totalAmount;
  var subtotal;
  var extraChargesAmount;
  int? extraChargesPaymentMethod;
  String? extraChargesPaymentDate;
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
  var distance;
  var duration;
  int? seatCount;
  String? reason;
  String? status;
  num? baseFare;
  num? distancePrice;
  num? discountAmount;
  num? timePrice;
  num? surgeAmount;
  num? minimumDistance;
  num? dropoffDistanceInKm;
  num? minimumFare;
  num? perDistance;
  num? perMinuteDrive;
  num? perMinuteWaiting;
  num? waitingTime;
  num? waitingTimeLimit;
  num? waitingTimeCharges;
  num? cancelationCharges;
  String? cancelBy;
  int? paymentId;
  String? paymentType;
  String? paymentStatus;
  List<ExtraChargeRequestModel>? extraCharges;
  num? couponDiscount;
  int? couponCode;
  CouponData? couponData;
  int? isRiderRated;
  int? isDriverRated;
  int? maxTimeForFindDriverForRideRequest;
  String? createdAt;
  String? updatedAt;
  num? perMinuteWaitingCharge;
  num? surgeCharge;
  num? bidAmount;
  num? perMinuteDriveCharge;
  num? perDistanceCharge;
  String? driverContactNumber;
  String? riderContactNumber;
  OtherRiderData? otherRiderData;
  num? tips;
  List<MultiDropLocation>? multiDropLocation;
  var estimated_price;

  RiderModel({
    this.id,
    this.riderId,
    this.serviceId,
    this.datetime,
    this.isSchedule,
    this.rideAttempt,
    this.multiDropLocation,
    this.estimated_price,
    this.otp,
    this.bidAmount,
    this.surgeCharge,
    this.adminCommission,
    this.totalAmount,
    this.subtotal,
    this.extraChargesAmount,
    this.extraChargesPaymentMethod,
    this.extraChargesPaymentDate,
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
    this.distancePrice,
    this.discountAmount,
    this.timePrice,
    this.surgeAmount,
    this.minimumDistance,
    this.dropoffDistanceInKm,
    this.minimumFare,
    this.ride_has_bids,
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
    this.perDistanceCharge,
    this.perMinuteDriveCharge,
    this.perMinuteWaitingCharge,
    this.driverContactNumber,
    this.riderContactNumber,
    this.otherRiderData,
    this.tips,
  });

  RiderModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    riderId = json['rider_id'];
    serviceId = json['service_id'];
    datetime = json['datetime'];
    ride_has_bids = int.tryParse(json['ride_has_bids'].toString());
    isSchedule = json['is_schedule'];
    rideAttempt = json['ride_attempt'];
    otp = json['otp'];
    adminCommission = num.tryParse(json['admin_commission'].toString()) ?? 0;
    totalAmount = num.tryParse(json['total_amount'].toString()) ?? 0;
    subtotal = num.tryParse(json['subtotal'].toString()) ?? 0;
    extraChargesAmount = num.tryParse(json['extra_charges_amount'].toString()) ?? 0;
    extraChargesPaymentMethod = json['extra_charges_payment_method'];
    extraChargesPaymentDate = json['extra_charges_payment_date'];
    driverId = json['driver_id'];
    driverName = json['driver_name'];
    riderName = json['rider_name'];
    driverProfileImage = json['driver_profile_image'];
    riderProfileImage = json['rider_profile_image'];
    startLatitude = json['start_latitude'];
    startLongitude = json['start_longitude'];
    startAddress = json['start_address'];
    endLatitude = json['end_latitude'];
    endLongitude = json['end_longitude'];
    endAddress = json['end_address'];
    distanceUnit = json['distance_unit'];
    startTime = json['start_time'];
    bidAmount = json['bid_amount'] == null ? null : num.tryParse(json['bid_amount'].toString());
    if (json['multi_drop_location'] != null) {
      multiDropLocation = <MultiDropLocation>[];
      json['multi_drop_location'].forEach((v) {
        multiDropLocation!.add(new MultiDropLocation.fromJson(v));
      });
    }
    estimated_price = json['estimated_price'];
    if (json['extra_charges'] != null) {
      extraCharges = <ExtraChargeRequestModel>[];
      json['extra_charges'].forEach((v) {
        extraCharges!.add(new ExtraChargeRequestModel.fromJson(v));
      });
    }
    endTime = json['end_time'];
    distance = json['distance'];
    duration = json['duration'];
    seatCount = json['seat_count'];
    reason = json['reason'];
    status = json['status'];
    baseFare = num.tryParse(json['base_fare'].toString()) ?? 0;
    distancePrice = num.tryParse(json['distance_price'].toString()) ?? 0;
    discountAmount = num.tryParse(json['discount_amount'].toString()) ?? 0;
    timePrice = num.tryParse(json['time_price'].toString()) ?? 0;
    surgeAmount = num.tryParse(json['surge_amount'].toString()) ?? 0;
    minimumDistance = num.tryParse(json['minimum_distance'].toString()) ?? 0;
    dropoffDistanceInKm = num.tryParse(json['dropoff_distance_in_km'].toString()) ?? 0;
    minimumFare = num.tryParse(json['minimum_fare'].toString()) ?? 0;
    perDistance = num.tryParse(json['per_distance'].toString()) ?? 0;
    perMinuteDrive = num.tryParse(json['per_minute_drive'].toString()) ?? 0;
    perMinuteWaiting = num.tryParse(json['per_minute_waiting'].toString()) ?? 0;
    waitingTimeCharges = num.tryParse(json['waiting_time_charges'].toString()) ?? 0;
    cancelationCharges = num.tryParse(json['cancelation_charges'].toString()) ?? 0;
    waitingTime = num.tryParse(json['waiting_time'].toString()) ?? 0;
    waitingTimeLimit = num.tryParse(json['waiting_time_limit'].toString()) ?? 0;
    cancelBy = json['cancel_by'];
    paymentId = json['payment_id'];
    paymentType = json['payment_type'];
    paymentStatus = json['payment_status'];
    riderContactNumber = json['rider_contact_number'];
    driverContactNumber = json['driver_contact_number'];
    surgeCharge = num.tryParse(json['fixed_charge'].toString());
    couponDiscount = num.tryParse(json['coupon_discount'].toString()) ?? 0;
    ;
    couponCode = json['coupon_code'];
    couponData = json['coupon_data'] != null ? CouponData.fromJson(json['coupon_data']) : null;
    isRiderRated = json['is_rider_rated'];
    isDriverRated = json['is_driver_rated'];
    maxTimeForFindDriverForRideRequest = json['max_time_for_find_driver_for_ride_request'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    perDistanceCharge = num.tryParse(json['per_distance_charge'].toString()) ?? 0;
    ;
    perMinuteDriveCharge = num.tryParse(json['per_minute_drive_charge'].toString()) ?? 0;
    ;
    perMinuteWaitingCharge = num.tryParse(json['per_minute_waiting_charge'].toString()) ?? 0;
    ;
    tips = num.tryParse(json['tips'].toString()) ?? 0;
    ;
    otherRiderData = json['other_rider_data'] != null ? new OtherRiderData.fromJson(json['other_rider_data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['rider_id'] = this.riderId;
    data['bid_amount'] = this.bidAmount;
    data['service_id'] = this.serviceId;
    data['datetime'] = this.datetime;
    data['fixed_charge'] = this.surgeCharge;
    data['is_schedule'] = this.isSchedule;
    data['ride_attempt'] = this.rideAttempt;
    data['otp'] = this.otp;
    data['admin_commission'] = this.adminCommission;
    data['total_amount'] = this.totalAmount;
    data['subtotal'] = this.subtotal;
    data['extra_charges_amount'] = this.extraChargesAmount;
    data['extra_charges_payment_method'] = this.extraChargesPaymentMethod;
    data['extra_charges_payment_date'] = this.extraChargesPaymentDate;
    data['driver_id'] = this.driverId;
    data['driver_name'] = this.driverName;
    data['rider_name'] = this.riderName;
    data['ride_has_bids'] = this.ride_has_bids;
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
    data['distance_price'] = this.distancePrice;
    data['discount_amount'] = this.discountAmount;
    data['time_price'] = this.timePrice;
    data['surge_amount'] = this.surgeAmount;
    data['minimum_distance'] = this.minimumDistance;
    data['dropoff_distance_in_km'] = this.dropoffDistanceInKm;
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
    data['estimated_price'] = this.estimated_price;
    data['coupon_discount'] = this.couponDiscount;
    data['coupon_code'] = this.couponCode;
    data['coupon_data'] = this.couponData;
    data['is_rider_rated'] = this.isRiderRated;
    data['is_driver_rated'] = this.isDriverRated;
    data['max_time_for_find_driver_for_ride_request'] = this.maxTimeForFindDriverForRideRequest;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['per_distance_charge'] = this.perDistanceCharge;
    data['per_minute_drive_charge'] = this.perMinuteDriveCharge;
    data['per_minute_waiting_charge'] = this.perMinuteWaitingCharge;
    data['rider_contact_number'] = this.perMinuteDriveCharge;
    data['driver_contact_number'] = this.perMinuteWaitingCharge;
    data['tips'] = this.tips;
    if (this.otherRiderData != null) {
      data['other_rider_data'] = this.otherRiderData!.toJson();
    }
    return data;
  }
}

class OtherRiderData {
  String? name;
  String? conatctNumber;

  OtherRiderData({this.name, this.conatctNumber});

  OtherRiderData.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    conatctNumber = json['contact_number'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['contact_number'] = this.conatctNumber;
    return data;
  }
}

class MultiDropLocation {
  int drop;
  double lat;
  double lng;
  dynamic droppedAt;
  String address;

  MultiDropLocation({
    required this.drop,
    required this.lat,
    required this.lng,
    required this.droppedAt,
    required this.address,
  });

  factory MultiDropLocation.fromJson(Map<String, dynamic> json) => MultiDropLocation(
        drop: int.tryParse(json["drop"].toString()) ?? 0,
        lat: double.tryParse(json["lat"].toString()) ?? 0.0,
        lng: double.tryParse(json["lng"].toString()) ?? 0.0,
        droppedAt: json["dropped_at"],
        address: json["address"].toString(),
      );

  Map<String, dynamic> toJson() => {
        "drop": drop,
        "lat": lat,
        "lng": lng,
        "dropped_at": droppedAt,
        "address": address,
      };
}
