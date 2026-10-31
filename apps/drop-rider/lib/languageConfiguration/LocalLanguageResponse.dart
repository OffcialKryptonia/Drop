import '../manage_imports.dart';

class LocalLanguageResponse {

  List<ContentData>? keywordData;

  LocalLanguageResponse({this.keywordData});

  LocalLanguageResponse.fromJson(Map<String, dynamic> json) {
    if (json['keyword_data'] != null) {
      keywordData = <ContentData>[];
      json['keyword_data'].forEach((v) {
        keywordData!.add(new ContentData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.keywordData != null) {
      data['keyword_data'] = this.keywordData!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
