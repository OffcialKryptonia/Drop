class ServerLanguageResponse {
  bool? status;
  int? currentVersionNo;
  List<LanguageJsonData>? data;
  dynamic rider_version;

  ServerLanguageResponse(
      {this.status, this.rider_version, this.data, this.currentVersionNo});

  ServerLanguageResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    rider_version = json['rider_version'];
    currentVersionNo = int.tryParse(json['version_code'].toString());
    if (json['data'] != null) {
      data = <LanguageJsonData>[];
      json['data'].forEach((v) {
        data!.add(new LanguageJsonData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['rider_version'] = this.rider_version;
    data['version_code'] = this.currentVersionNo;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class LanguageJsonData {
  String? languageName;
  String? languageCode;
  String? countryCode;
  String? languageImage;
  int? isDefaultLanguage;
  List<ContentData>? contentData;

  LanguageJsonData(
      {
      this.languageName,
      this.contentData,
      this.isDefaultLanguage,
      this.languageCode,
      this.countryCode,
      this.languageImage});

  LanguageJsonData.fromJson(Map<String, dynamic> json) {
    languageName = json['language_name'];
    isDefaultLanguage = int.tryParse(json['id_default_language'].toString());
    languageCode = json['language_code'] == null ? "en" : json['language_code'];
    countryCode = json['country_code'];
    if (json['contentdata'] != null) {
      contentData = <ContentData>[];
      json['contentdata'].forEach((v) {
        contentData!.add(new ContentData.fromJson(v));
      });
    }
    languageImage = json['language_image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['language_name'] = this.languageName;
    data['country_code'] = this.countryCode;
    data['language_code'] = this.languageCode;
    data['id_default_language'] = this.isDefaultLanguage;
    if (this.contentData != null) {
      data['contentdata'] = this.contentData!.map((v) => v.toJson()).toList();
    }
    data['language_image'] = this.languageImage;
    return data;
  }
}

class ContentData {
  int? keywordId;
  String? keywordName;
  String? keywordValue;

  ContentData({this.keywordId, this.keywordName, this.keywordValue});

  ContentData.fromJson(Map<String, dynamic> json) {
    keywordId = int.tryParse(json['keyword_id'].toString());

    keywordName = json['keyword_name'];

    keywordValue = json['keyword_value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['keyword_id'] = this.keywordId;
    data['keyword_name'] = this.keywordName;
    data['keyword_value'] = this.keywordValue;
    return data;
  }
}
