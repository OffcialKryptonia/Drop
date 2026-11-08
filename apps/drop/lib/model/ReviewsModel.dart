import 'dart:convert';

ReviewsModel reviewsModelFromJson(String str) => ReviewsModel.fromJson(json.decode(str));

String reviewsModelToJson(ReviewsModel data) => json.encode(data.toJson());

class ReviewsModel {
  ReviewsModel({
    required this.pagination,
    required this.data,
  });

  Pagination pagination;
  List<ReviewsList> data;

  factory ReviewsModel.fromJson(Map<dynamic, dynamic> json) => ReviewsModel(
        pagination: Pagination.fromJson(json["pagination"]),
        data: List<ReviewsList>.from(json["data"].map((x) => ReviewsList.fromJson(x))),
      );

  Map<dynamic, dynamic> toJson() => {
        "pagination": pagination.toJson(),
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class ReviewsList {
  ReviewsList({
    required this.ratingBy,
    required this.driverId,
    required this.rideRequestId,
    required this.updatedAt,
    required this.driver,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.id,
    required this.riderId,
    required this.rider,
    required this.rideRequest,
  });

  String ratingBy;
  int driverId;
  int rideRequestId;
  DateTime updatedAt;
  Driver driver;
  int rating;
  String? comment;
  DateTime createdAt;
  int id;
  int riderId;
  Driver rider;
  RideRequest rideRequest;

  factory ReviewsList.fromJson(Map<dynamic, dynamic> json) => ReviewsList(
        ratingBy: json["rating_by"],
        driverId: json["driver_id"],
        rideRequestId: json["ride_request_id"],
        updatedAt: DateTime.parse(json["updated_at"]),
        driver: Driver.fromJson(json["driver"]),
        rating: json["rating"],
        comment: json["comment"] ?? '',
        createdAt: DateTime.parse(json["created_at"]),
        id: json["id"],
        riderId: json["rider_id"],
        rider: Driver.fromJson(json["rider"]),
        rideRequest: RideRequest.fromJson(json["ride_request"]),
      );

  Map<dynamic, dynamic> toJson() => {
        "rating_by": ratingBy,
        "driver_id": driverId,
        "ride_request_id": rideRequestId,
        "updated_at": updatedAt.toIso8601String(),
        "driver": driver.toJson(),
        "rating": rating,
        "comment": comment,
        "created_at": createdAt.toIso8601String(),
        "id": id,
        "rider_id": riderId,
        "rider": rider.toJson(),
        "ride_request": rideRequest.toJson(),
      };
}

class Driver {
  Driver({
    required this.profileImage,
    required this.id,
    required this.displayName,
  });

  String profileImage;
  int id;
  String displayName;

  factory Driver.fromJson(Map<dynamic, dynamic> json) => Driver(
        profileImage: json["profile_image"],
        id: json["id"],
        displayName: json["display_name"],
      );

  Map<dynamic, dynamic> toJson() => {
        "profile_image": profileImage,
        "id": id,
        "display_name": displayName,
      };
}

enum DisplayName { MOHIT_M, MOHIT_RIDER, MANAN_PATEL }

final displayNameValues = EnumValues({"Manan patel": DisplayName.MANAN_PATEL, "mohit M": DisplayName.MOHIT_M, "Mohit rider": DisplayName.MOHIT_RIDER});

enum RatingBy { RIDER }

final ratingByValues = EnumValues({"rider": RatingBy.RIDER});

class RideRequest {
  RideRequest({
    required this.datetime,
    required this.startAddress,
    required this.id,
    this.endAddress,
    required this.status,
  });

  DateTime datetime;
  String startAddress;
  int id;
  String? endAddress;
  Status status;

  factory RideRequest.fromJson(Map<dynamic, dynamic> json) => RideRequest(
        datetime: DateTime.parse(json["datetime"]),
        startAddress: json["start_address"],
        id: json["id"],
        endAddress: json["end_address"],
        status: statusValues.map[json["status"]]!,
      );

  Map<dynamic, dynamic> toJson() => {
        "datetime": datetime.toIso8601String(),
        "start_address": startAddress,
        "id": id,
        "end_address": endAddress,
        "status": statusValues.reverse[status],
      };
}

enum Status { COMPLETED }

final statusValues = EnumValues({"completed": Status.COMPLETED});

class Pagination {
  Pagination({
    required this.perPage,
    required this.totalPages,
    required this.currentPage,
    required this.totalItems,
  });

  int perPage;
  int totalPages;
  int currentPage;
  int totalItems;

  factory Pagination.fromJson(Map<dynamic, dynamic> json) => Pagination(
        perPage: json["per_page"],
        totalPages: json["totalPages"],
        currentPage: json["currentPage"],
        totalItems: json["total_items"],
      );

  Map<dynamic, dynamic> toJson() => {
        "per_page": perPage,
        "totalPages": totalPages,
        "currentPage": currentPage,
        "total_items": totalItems,
      };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
