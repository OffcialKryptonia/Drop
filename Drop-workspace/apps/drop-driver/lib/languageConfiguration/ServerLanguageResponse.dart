class ServerLanguageResponse {
  bool? status;
  int? currentVersionNo;
  List<LanguageJsonData>? data;
  dynamic driver_version;

  ServerLanguageResponse(
      {this.status, this.driver_version, this.data, this.currentVersionNo});

  ServerLanguageResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    currentVersionNo = int.tryParse(json['version_code'].toString());
    driver_version = json['driver_version'];
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
    data['driver_version'] = this.driver_version;
    data['version_code'] = this.currentVersionNo;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class LanguageJsonData {
  int? id;
  String? languageName;
  String? languageCode;
  String? countryCode;
  String? languageImage;
  int? isRtl;
  int? isDefaultLanguage;
  List<ContentData>? contentData;
  String? createdAt;
  String? updatedAt;

  LanguageJsonData(
      {this.id,
      this.languageName,
      this.isRtl,
      this.contentData,
      this.isDefaultLanguage,
      this.createdAt,
      this.updatedAt,
      this.languageCode,
      this.countryCode,
      this.languageImage});

  LanguageJsonData.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'].toString());
    languageName = json['language_name'];
    isDefaultLanguage = int.tryParse(json['id_default_language'].toString());
    languageCode = json['language_code'] == null ? "en" : json['language_code'];
    countryCode = json['country_code'];
    isRtl = int.tryParse(json['is_rtl'].toString());
    if (json['contentdata'] != null) {
      contentData = <ContentData>[];
      json['contentdata'].forEach((v) {
        contentData!.add(new ContentData.fromJson(v));
      });
    }
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    languageImage = json['language_image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['language_name'] = this.languageName;
    data['country_code'] = this.countryCode;
    data['language_code'] = this.languageCode;
    data['id_default_language'] = this.isDefaultLanguage;
    data['is_rtl'] = this.isRtl;
    if (this.contentData != null) {
      data['contentdata'] = this.contentData!.map((v) => v.toJson()).toList();
    }
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
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
