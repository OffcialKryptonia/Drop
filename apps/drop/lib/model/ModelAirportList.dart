import '../manage_imports.dart';

ModelAirportList modelAirportListFromJson(String str) =>
    ModelAirportList.fromJson(json.decode(str));

String modelAirportListToJson(ModelAirportList data) =>
    json.encode(data.toJson());

class ModelAirportList {
  PaginationModel? pagination;
  List<AirportItem>? data;

  ModelAirportList({
    this.pagination,
    this.data,
  });

  factory ModelAirportList.fromJson(Map<String, dynamic> json) =>
      ModelAirportList(
        pagination: json["pagination"] == null
            ? null
            : PaginationModel.fromJson(json["pagination"]),
        data: json["data"] == null
            ? []
            : List<AirportItem>.from(
                json["data"]!.map((x) => AirportItem.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "pagination": pagination?.toJson(),
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class AirportItem {
  int? id;
  int? airportId;
  String? ident;
  dynamic type;
  String? name;
  String? latitudeDeg;
  String? longitudeDeg;
  IsoCountry? isoCountry;
  String? isoRegion;
  String? municipality;
  DateTime? createdAt;
  DateTime? updatedAt;

  AirportItem({
    this.id,
    this.airportId,
    this.ident,
    this.type,
    this.name,
    this.latitudeDeg,
    this.longitudeDeg,
    this.isoCountry,
    this.isoRegion,
    this.municipality,
    this.createdAt,
    this.updatedAt,
  });

  factory AirportItem.fromJson(Map<String, dynamic> json) => AirportItem(
        id: json["id"],
        airportId: json["airport_id"],
        ident: json["ident"],
        type: json["type"],
        name: json["name"],
        latitudeDeg: json["latitude_deg"],
        longitudeDeg: json["longitude_deg"],
        isoCountry: isoCountryValues.map[json["iso_country"]],
        isoRegion: json["iso_region"],
        municipality: json["municipality"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "airport_id": airportId,
        "ident": ident,
        "type": type,
        "name": name,
        "latitude_deg": latitudeDeg,
        "longitude_deg": longitudeDeg,
        "iso_country": isoCountryValues.reverse[isoCountry],
        "iso_region": isoRegion,
        "municipality": municipality,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

enum IsoCountry { US }

final isoCountryValues = EnumValues({"US": IsoCountry.US});

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
