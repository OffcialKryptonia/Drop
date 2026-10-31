import '../manage_imports.dart';

ModelSearchPlaceRes modelSearchPlaceResFromJson(String str) =>
    ModelSearchPlaceRes.fromJson(json.decode(str));

String modelSearchPlaceResToJson(ModelSearchPlaceRes data) =>
    json.encode(data.toJson());

class ModelSearchPlaceRes {
  List<Suggestion>? suggestions;

  ModelSearchPlaceRes({
    this.suggestions,
  });

  factory ModelSearchPlaceRes.fromJson(Map<String, dynamic> json) =>
      ModelSearchPlaceRes(
        suggestions: json["suggestions"] == null
            ? []
            : List<Suggestion>.from(
                json["suggestions"]!.map((x) => Suggestion.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "suggestions": suggestions == null
            ? []
            : List<dynamic>.from(suggestions!.map((x) => x.toJson())),
      };
}

class Suggestion {
  PlacePrediction? placePrediction;

  Suggestion({
    this.placePrediction,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
        placePrediction: json["placePrediction"] == null
            ? null
            : PlacePrediction.fromJson(json["placePrediction"]),
      );

  Map<String, dynamic> toJson() => {
        "placePrediction": placePrediction?.toJson(),
      };
}

class PlacePrediction {
  String? place;
  String? placeId;
  MyText? text;
  StructuredFormat? structuredFormat;
  List<String>? types;

  PlacePrediction({
    this.place,
    this.placeId,
    this.text,
    this.structuredFormat,
    this.types,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) =>
      PlacePrediction(
        place: json["place"],
        placeId: json["placeId"],
        text: json["text"] == null ? null : MyText.fromJson(json["text"]),
        structuredFormat: json["structuredFormat"] == null
            ? null
            : StructuredFormat.fromJson(json["structuredFormat"]),
        types: json["types"] == null
            ? []
            : List<String>.from(json["types"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "place": place,
        "placeId": placeId,
        "text": text?.toJson(),
        "structuredFormat": structuredFormat?.toJson(),
        "types": types == null ? [] : List<dynamic>.from(types!.map((x) => x)),
      };
}

class StructuredFormat {
  MyText? mainText;
  SecondaryText? secondaryText;

  StructuredFormat({
    this.mainText,
    this.secondaryText,
  });

  factory StructuredFormat.fromJson(Map<String, dynamic> json) =>
      StructuredFormat(
        mainText:
            json["mainText"] == null ? null : MyText.fromJson(json["mainText"]),
        secondaryText: json["secondaryText"] == null
            ? null
            : SecondaryText.fromJson(json["secondaryText"]),
      );

  Map<String, dynamic> toJson() => {
        "mainText": mainText?.toJson(),
        "secondaryText": secondaryText?.toJson(),
      };
}

class MyText {
  String? text;
  List<Match>? matches;

  MyText({
    this.text,
    this.matches,
  });

  factory MyText.fromJson(Map<String, dynamic> json) => MyText(
        text: json["text"],
        matches: json["matches"] == null
            ? []
            : List<Match>.from(json["matches"]!.map((x) => Match.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "text": text,
        "matches": matches == null
            ? []
            : List<dynamic>.from(matches!.map((x) => x.toJson())),
      };
}

class Match {
  int? endOffset;

  Match({
    this.endOffset,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        endOffset: json["endOffset"],
      );

  Map<String, dynamic> toJson() => {
        "endOffset": endOffset,
      };
}

class SecondaryText {
  String? text;

  SecondaryText({
    this.text,
  });

  factory SecondaryText.fromJson(Map<String, dynamic> json) => SecondaryText(
        text: json["text"],
      );

  Map<String, dynamic> toJson() => {
        "text": text,
      };
}
