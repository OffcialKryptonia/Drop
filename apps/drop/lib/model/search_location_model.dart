import 'dart:convert';

SearchLocationModel searchLocationModelFromJson(String str) => SearchLocationModel.fromJson(json.decode(str));

String searchLocationModelToJson(SearchLocationModel data) => json.encode(data.toJson());

class SearchLocationModel {
  SearchLocationModel({
    required this.suggestions,
  });

  List<Suggestion> suggestions;

  factory SearchLocationModel.fromJson(Map<dynamic, dynamic> json) => SearchLocationModel(
        suggestions: List<Suggestion>.from(json["suggestions"].map((x) => Suggestion.fromJson(x))),
      );

  Map<dynamic, dynamic> toJson() => {
        "suggestions": List<dynamic>.from(suggestions.map((x) => x.toJson())),
      };
}

class Suggestion {
  Suggestion({
    required this.placePrediction,
  });

  PlacePrediction placePrediction;

  factory Suggestion.fromJson(Map<dynamic, dynamic> json) => Suggestion(
        placePrediction: PlacePrediction.fromJson(json["placePrediction"]),
      );

  Map<dynamic, dynamic> toJson() => {
        "placePrediction": placePrediction.toJson(),
      };
}

class PlacePrediction {
  PlacePrediction({
    required this.types,
    required this.placeId,
    required this.structuredFormat,
    required this.place,
    required this.text,
  });

  List<String> types;
  String placeId;
  StructuredFormat structuredFormat;
  String place;
  Text text;

  factory PlacePrediction.fromJson(Map<dynamic, dynamic> json) => PlacePrediction(
        types: List<String>.from(json["types"].map((x) => x)),
        placeId: json["placeId"],
        structuredFormat: StructuredFormat.fromJson(json["structuredFormat"]),
        place: json["place"],
        text: Text.fromJson(json["text"]),
      );

  Map<dynamic, dynamic> toJson() => {
        "types": List<dynamic>.from(types.map((x) => x)),
        "placeId": placeId,
        "structuredFormat": structuredFormat.toJson(),
        "place": place,
        "text": text.toJson(),
      };
}

class StructuredFormat {
  StructuredFormat({
    required this.mainText,
    required this.secondaryText,
  });

  Text mainText;
  SecondaryText secondaryText;

  factory StructuredFormat.fromJson(Map<dynamic, dynamic> json) => StructuredFormat(
        mainText: Text.fromJson(json["mainText"]),
        secondaryText: SecondaryText.fromJson(json["secondaryText"]),
      );

  Map<dynamic, dynamic> toJson() => {
        "mainText": mainText.toJson(),
        "secondaryText": secondaryText.toJson(),
      };
}

class Text {
  Text({
    required this.text,
    required this.matches,
  });

  String text;
  List<Match> matches;

  factory Text.fromJson(Map<dynamic, dynamic> json) => Text(
        text: json["text"],
        matches: List<Match>.from(json["matches"].map((x) => Match.fromJson(x))),
      );

  Map<dynamic, dynamic> toJson() => {
        "text": text,
        "matches": List<dynamic>.from(matches.map((x) => x.toJson())),
      };
}

class Match {
  Match({
    required this.endOffset,
  });

  int endOffset;

  factory Match.fromJson(Map<dynamic, dynamic> json) => Match(
        endOffset: json["endOffset"],
      );

  Map<dynamic, dynamic> toJson() => {
        "endOffset": endOffset,
      };
}

class SecondaryText {
  SecondaryText({
    required this.text,
  });

  String text;

  factory SecondaryText.fromJson(Map<dynamic, dynamic> json) => SecondaryText(
        text: json["text"],
      );

  Map<dynamic, dynamic> toJson() => {
        "text": text,
      };
}
