// To parse this JSON data, do
//
//     final modelBidData = modelBidDataFromJson(jsonString);

import 'dart:convert';

ModelBidData modelBidDataFromJson(String str) =>
    ModelBidData.fromJson(json.decode(str));

String modelBidDataToJson(ModelBidData data) => json.encode(data.toJson());

class ModelBidData {
  int? id;
  int? rideRequestId;
  int? driverId;
  String? bidAmount;
  String? notes;
  int? isBidAccept;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? multiDropLocation;

  ModelBidData({
    this.id,
    this.rideRequestId,
    this.driverId,
    this.bidAmount,
    this.notes,
    this.isBidAccept,
    this.createdAt,
    this.updatedAt,
    this.multiDropLocation,
  });

  factory ModelBidData.fromJson(Map<String, dynamic> json) => ModelBidData(
        id: json["id"],
        rideRequestId: json["ride_request_id"],
        driverId: json["driver_id"],
        bidAmount: json["bid_amount"],
        notes: json["notes"],
        isBidAccept: json["is_bid_accept"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        multiDropLocation: json["multi_drop_location"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "ride_request_id": rideRequestId,
        "driver_id": driverId,
        "bid_amount": bidAmount,
        "notes": notes,
        "is_bid_accept": isBidAccept,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "multi_drop_location": multiDropLocation,
      };
}
