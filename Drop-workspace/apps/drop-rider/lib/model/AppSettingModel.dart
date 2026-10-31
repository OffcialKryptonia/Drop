import '../manage_imports.dart';

class AppSettingModel {
  SettingModel? settingModel;
  List<RideSetting>? rideSetting;
  List<WalletSetting>? walletSetting;
  CurrencySetting? currencySetting;
  PrivacyPolicyModel? privacyPolicyModel;
  PrivacyPolicyModel? termsCondition;
  String? reference_amount;
  String? maxEarningPerMonth;
  String? reference_type;

  AppSettingModel(
      {this.reference_type,
      this.maxEarningPerMonth,
      this.reference_amount,
      this.rideSetting,
      this.walletSetting,
      this.currencySetting,
      this.settingModel,
      this.privacyPolicyModel,
      this.termsCondition});

  AppSettingModel.fromJson(Map<String, dynamic> json) {
    reference_type = json['reference_type'];
    maxEarningPerMonth = json['maxEarningPerMonth']??"0";
    reference_amount = json['reference_amount']??"0";
    settingModel = json['app_seeting'] != null
        ? new SettingModel.fromJson(json['app_seeting'])
        : null;
    if (json['ride_setting'] != null) {
      rideSetting = <RideSetting>[];
      json['ride_setting'].forEach((v) {
        rideSetting!.add(new RideSetting.fromJson(v));
      });
    }
    if (json['Wallet_setting'] != null) {
      walletSetting = <WalletSetting>[];
      json['Wallet_setting'].forEach((v) {
        walletSetting!.add(new WalletSetting.fromJson(v));
      });
    }
    currencySetting = json['currency_setting'] != null
        ? new CurrencySetting.fromJson(json['currency_setting'])
        : null;
    privacyPolicyModel = json['privacy_policy'] != null
        ? new PrivacyPolicyModel.fromJson(json['privacy_policy'])
        : null;
    termsCondition = json['terms_condition'] != null
        ? new PrivacyPolicyModel.fromJson(json['terms_condition'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['reference_type'] = this.reference_type;
    data['maxEarningPerMonth'] = this.maxEarningPerMonth;
    data['reference_amount'] = this.reference_amount;
    if (this.settingModel != null) {
      data['app_seeting'] = this.settingModel!.toJson();
    }
    if (this.rideSetting != null) {
      data['ride_setting'] = this.rideSetting!.map((v) => v.toJson()).toList();
    }
    if (this.walletSetting != null) {
      data['Wallet_setting'] =
          this.walletSetting!.map((v) => v.toJson()).toList();
    }
    if (this.currencySetting != null) {
      data['currency_setting'] = this.currencySetting!.toJson();
    }
    if (this.privacyPolicyModel != null) {
      data['privacy_policy'] = this.privacyPolicyModel!.toJson();
    }
    if (this.termsCondition != null) {
      data['terms_condition'] = this.termsCondition!.toJson();
    }
    return data;
  }
}

class WalletSetting {
  int? id;
  String? key;
  String? type;
  String? value;

  WalletSetting({this.id, this.key, this.type, this.value});

  WalletSetting.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    key = json['key'];
    type = json['type'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['key'] = this.key;
    data['type'] = this.type;
    data['value'] = this.value;
    return data;
  }
}

class RideSetting {
  int? id;
  String? key;
  String? type;
  String? value;

  RideSetting({this.id, this.key, this.type, this.value});

  RideSetting.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    key = json['key'];
    type = json['type'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['key'] = this.key;
    data['type'] = this.type;
    data['value'] = this.value;
    return data;
  }
}

class CurrencySetting {
  String? name;
  String? code;
  String? symbol;
  String? position;

  CurrencySetting({this.name, this.code, this.position, this.symbol});

  CurrencySetting.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    code = json['code'];
    position = json['position'];
    symbol = json['symbol'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['code'] = this.code;
    data['position'] = this.position;
    data['symbol'] = this.symbol;
    return data;
  }
}

class PrivacyPolicyModel {
  int? id;
  String? key;
  String? type;
  String? value;

  PrivacyPolicyModel({this.id, this.key, this.type, this.value});

  factory PrivacyPolicyModel.fromJson(Map<String, dynamic> json) {
    return PrivacyPolicyModel(
      id: json['id'],
      key: json['key'],
      type: json['type'],
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['key'] = this.key;
    data['type'] = this.type;
    data['value'] = this.value;
    return data;
  }
}
