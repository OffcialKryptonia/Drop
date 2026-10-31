import '../manage_imports.dart';

ModelZoneList modelZoneListFromJson(String str) =>
    ModelZoneList.fromJson(json.decode(str));

String modelZoneListToJson(ModelZoneList data) => json.encode(data.toJson());

class ModelZoneList {
  PaginationModel? pagination;
  List<ZoneItem>? data;

  ModelZoneList({
    this.pagination,
    this.data,
  });

  factory ModelZoneList.fromJson(Map<String, dynamic> json) => ModelZoneList(
        pagination: json["pagination"] == null
            ? null
            : PaginationModel.fromJson(json["pagination"]),
        data: json["data"] == null
            ? []
            : List<ZoneItem>.from(
                json["data"]!.map((x) => ZoneItem.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "pagination": pagination?.toJson(),
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class ZoneItem {
  int? id;
  String? name;
  String? latitude;
  String? longitude;
  String? description;
  DateTime? createdAt;
  DateTime? updatedAt;

  ZoneItem({
    this.id,
    this.name,
    this.latitude,
    this.longitude,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory ZoneItem.fromJson(Map<String, dynamic> json) => ZoneItem(
        id: int.tryParse(json["id"].toString()),
        name: json["name"],
        latitude: json["latitude"],
        longitude: json["longitude"],
        description: json["description"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "latitude": latitude,
        "longitude": longitude,
        "description": description,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
