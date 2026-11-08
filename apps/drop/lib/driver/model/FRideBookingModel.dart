class FRideBookingModel {
  int? riderId;
  var driverID;
  List<int>? driver_ids;
  List<int>? nearby_driver_ids;
  int? rideId;
  int? ride_has_bid;
  String? status;
  String? paymentType;
  int? onStreamApiCall;
  int? onRiderStreamApiCall;
  int? tips;
  String? paymentStatus;

  FRideBookingModel({
    this.riderId,
    this.driverID,
    this.rideId,
    this.driver_ids,
    this.nearby_driver_ids,
    this.paymentStatus,
    this.ride_has_bid,
    this.status,
    this.paymentType,
    this.tips,
    this.onStreamApiCall = 0,
    this.onRiderStreamApiCall = 0,
  });

  FRideBookingModel.fromJson(Map<String, dynamic> json) {
    json['nearby_driver_ids'] != null ? List<int>.from(json["nearby_driver_ids"]!.map((x) => x)) : null;
    json['driver_ids'] != null ? List<int>.from(json["driver_ids"]!.map((x) => x)) : null;
    riderId = json["rider_id"];
    driverID = json["driver_id"];
    rideId = json["ride_id"];
    paymentStatus = json['payment_status'];
    status = json["status"];
    tips = int.tryParse(json["tips"].toString()) ?? null;
    ride_has_bid = int.tryParse(json["ride_has_bid"].toString()) ?? null;
    paymentType = json["payment_type"];
    onStreamApiCall = json["on_stream_api_call"];
    onRiderStreamApiCall = json["on_rider_stream_api_call"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data["rider_id"] = this.riderId;
    data["ride_id"] = this.rideId;
    data["driver_id"] = this.driverID;
    data["ride_has_bid"] = this.ride_has_bid;
    data['payment_status'] = this.paymentStatus;
    data["status"] = this.status;
    data["tips"] = this.tips;
    data["payment_type"] = this.paymentType;
    data["on_stream_api_call"] = this.onStreamApiCall;
    data["on_rider_stream_api_call"] = this.onRiderStreamApiCall;
    data["nearby_driver_ids"] = nearby_driver_ids == null ? [] : List<dynamic>.from(nearby_driver_ids!.map((x) => x));
    data["driver_ids"] = driver_ids == null ? [] : List<dynamic>.from(driver_ids!.map((x) => x));
    return data;
  }
}
