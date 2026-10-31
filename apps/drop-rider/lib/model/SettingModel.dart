class SettingModel {
  String? contactEmail;
  String? contactNumber;
  String? createdAt;
  String? facebookUrl;
  int? id;
  String? instagramUrl;
  String? linkedinUrl;
  String? helpSupportUrl;
  String? siteCopyright;
  String? siteDescription;
  String? siteEmail;
  String? siteFavicon;
  String? siteLogo;
  String? siteName;
  String? twitterUrl;
  String? updatedAt;

  SettingModel({
    this.contactEmail,
    this.contactNumber,
    this.createdAt,
    this.facebookUrl,
    this.id,
    this.instagramUrl,
    this.linkedinUrl,
    this.siteCopyright,
    this.siteDescription,
    this.siteEmail,
    this.siteFavicon,
    this.siteLogo,
    this.siteName,
    this.twitterUrl,
    this.updatedAt,
    this.helpSupportUrl,
  });

  factory SettingModel.fromJson(Map<String, dynamic> json) {
    return SettingModel(
      contactEmail: json['contact_email'],
      contactNumber: json['contact_number'],
      createdAt: json['created_at'],
      facebookUrl: json['facebook_url'],
      id: json['id'],
      instagramUrl: json['instagram_url'],
      linkedinUrl: json['linkedin_url'],
      siteCopyright: json['site_copyright'],
      siteDescription: json['site_description'],
      siteEmail: json['site_email'],
      siteFavicon: json['site_favicon'],
      siteLogo: json['site_logo'],
      siteName: json['site_name'],
      twitterUrl: json['twitter_url'],
      updatedAt: json['updated_at'],
      helpSupportUrl: json['help_support_url'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['contact_email'] = this.contactEmail;
    data['contact_number'] = this.contactNumber;
    data['created_at'] = this.createdAt;
    data['facebook_url'] = this.facebookUrl;
    data['id'] = this.id;
    data['instagram_url'] = this.instagramUrl;
    data['linkedin_url'] = this.linkedinUrl;
    data['site_copyright'] = this.siteCopyright;
    data['site_description'] = this.siteDescription;
    data['site_email'] = this.siteEmail;
    data['site_favicon'] = this.siteFavicon;
    data['site_logo'] = this.siteLogo;
    data['site_name'] = this.siteName;
    data['twitter_url'] = this.twitterUrl;
    data['updated_at'] = this.updatedAt;
    data['help_support_url'] = this.helpSupportUrl;
    return data;
  }
}
