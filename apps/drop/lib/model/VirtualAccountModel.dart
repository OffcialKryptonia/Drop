/// The rider's own bank account for topping up the wallet by transfer
/// (GET /api/wallet/virtual-account).
class VirtualAccountModel {
  VirtualAccountData? data;

  VirtualAccountModel({this.data});

  factory VirtualAccountModel.fromJson(Map<String, dynamic> json) {
    return VirtualAccountModel(
      data: json['data'] != null ? VirtualAccountData.fromJson(json['data']) : null,
    );
  }
}

class VirtualAccountData {
  String? provider;
  String? bankName;
  String? accountNumber;
  String? accountName;

  VirtualAccountData({this.provider, this.bankName, this.accountNumber, this.accountName});

  factory VirtualAccountData.fromJson(Map<String, dynamic> json) {
    return VirtualAccountData(
      provider: json['provider']?.toString(),
      bankName: json['bank_name']?.toString(),
      accountNumber: json['account_number']?.toString(),
      accountName: json['account_name']?.toString(),
    );
  }
}
