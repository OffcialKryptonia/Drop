import '../manage_imports.dart';

BidListingModel bidListingModelFromJson(String str) =>
    BidListingModel.fromJson(json.decode(str));

String bidListingModelToJson(BidListingModel data) =>
    json.encode(data.toJson());

class BidListingModel {
  bool? success;
  List<DriverItem>? data;
  String? startAddress;
  String? endAddress;
  String? multiDropLocation;

  BidListingModel({
    required this.success,
    required this.data,
    required this.startAddress,
    required this.endAddress,
    required this.multiDropLocation,
  });

  factory BidListingModel.fromJson(Map<String, dynamic> json) =>
      BidListingModel(
        success: json["success"],
        data: List<DriverItem>.from(
            json["data"].map((x) => DriverItem.fromJson(x))),
        startAddress: json["start_address"],
        endAddress: json["end_address"],
        multiDropLocation: json["multi_drop_location"] == null
            ? null
            : json["multi_drop_location"],
      );

  Map<String, dynamic> toJson() => {
        "success": success,
        "data": List<dynamic>.from(data!.map((x) => x.toJson())),
        "start_address": startAddress,
        "end_address": endAddress,
        "multi_drop_location": multiDropLocation,
      };
}

class DriverItem {
  int driverId;
  String driverName;
  String bidAmount;
  String notes;
  double distance;

  DriverItem({
    required this.driverId,
    required this.driverName,
    required this.bidAmount,
    required this.notes,
    required this.distance,
  });

  factory DriverItem.fromJson(Map<String, dynamic> json) => DriverItem(
        driverId: json["driver_id"],
        driverName: json["driver_name"],
        bidAmount: json["bid_amount"],
        notes: json["notes"] == null ? "" : json["notes"],
        distance: json["distance"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "driver_id": driverId,
        "driver_name": driverName,
        "bid_amount": bidAmount,
        "notes": notes,
        "distance": distance,
      };
}
