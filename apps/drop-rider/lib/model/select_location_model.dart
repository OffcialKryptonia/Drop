/// YApi QuickType插件生成，具体参考文档:https://plugins.jetbrains.com/plugin/18847-yapi-quicktype/documentation

import 'dart:convert';

SelectLocationModel selectLocationModelFromJson(String str) => SelectLocationModel.fromJson(json.decode(str));

String selectLocationModelToJson(SelectLocationModel data) => json.encode(data.toJson());

class SelectLocationModel {
  SelectLocationModel({
    required this.formattedAddress,
    required this.displayName,
    required this.location,
    required this.id,
  });

  String formattedAddress;
  DisplayName displayName;
  Location location;
  String id;

  factory SelectLocationModel.fromJson(Map<dynamic, dynamic> json) => SelectLocationModel(
        formattedAddress: json["formattedAddress"],
        displayName: DisplayName.fromJson(json["displayName"]),
        location: Location.fromJson(json["location"]),
        id: json["id"],
      );

  Map<dynamic, dynamic> toJson() => {
        "formattedAddress": formattedAddress,
        "displayName": displayName.toJson(),
        "location": location.toJson(),
        "id": id,
      };
}

class DisplayName {
  DisplayName({
    required this.text,
    required this.languageCode,
  });

  String text;
  String languageCode;

  factory DisplayName.fromJson(Map<dynamic, dynamic> json) => DisplayName(
        text: json["text"],
        languageCode: json["languageCode"],
      );

  Map<dynamic, dynamic> toJson() => {
        "text": text,
        "languageCode": languageCode,
      };
}

class Location {
  Location({
    required this.latitude,
    required this.longitude,
  });

  double latitude;
  double longitude;

  factory Location.fromJson(Map<dynamic, dynamic> json) => Location(
        latitude: json["latitude"]?.toDouble(),
        longitude: json["longitude"]?.toDouble(),
      );

  Map<dynamic, dynamic> toJson() => {
        "latitude": latitude,
        "longitude": longitude,
      };
}
