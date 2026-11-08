import '../manage_imports.dart';

class CoinWalletListModel {
  List<CoinWalletModel>? data;
  PaginationModel? pagination;
  num? totalCoins;

  CoinWalletListModel({this.data, this.pagination, this.totalCoins});

  factory CoinWalletListModel.fromJson(Map<String, dynamic> json) {
    return CoinWalletListModel(
      data: json['data'] != null
          ? (json['data'] as List).map((i) => CoinWalletModel.fromJson(i)).toList()
          : null,
      pagination: json['pagination'] != null
          ? PaginationModel.fromJson(json['pagination'])
          : null,
      totalCoins: json['total_coins'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (pagination != null) {
      data['pagination'] = pagination!.toJson();
    }
    data['total_coins'] = totalCoins;
    return data;
  }
}

class CoinWalletModel {
  int? id;
  int? userId;
  int? rideId;
  String? scratchTime;
  String? type; // 'credit' or 'debit'
  num? coins;
  String? createdAt;
  String? updatedAt;

  CoinWalletModel({
    this.id,
    this.userId,
    this.rideId,
    this.scratchTime,
    this.type,
    this.coins,
    this.createdAt,
    this.updatedAt,
  });

  factory CoinWalletModel.fromJson(Map<String, dynamic> json) {
    return CoinWalletModel(
      id: json['id'],
      userId: json['user_id'],
      rideId: json['ride_id'],
      scratchTime: json['scratch_time'],
      type: json['type'],
      coins: json['coins'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['ride_id'] = rideId;
    data['scratch_time'] = scratchTime;
    data['type'] = type;
    data['coins'] = coins;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
  }
}
