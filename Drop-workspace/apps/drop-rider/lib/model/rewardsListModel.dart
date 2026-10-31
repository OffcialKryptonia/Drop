import '../manage_imports.dart';

class RewardsListModel {
  List<RewardsModel>? data;
  PaginationModel? pagination;

  RewardsListModel({this.data, this.pagination});

  factory RewardsListModel.fromJson(Map<String, dynamic> json) {
    return RewardsListModel(
      data: json['data'] != null
          ? (json['data'] as List).map((i) => RewardsModel.fromJson(i)).toList()
          : null,
      pagination: json['pagination'] != null
          ? PaginationModel.fromJson(json['pagination'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (this.pagination != null) {
      data['pagination'] = this.pagination!.toJson();
    }
    return data;
  }
}

class RewardsModel {
  int? id;
  int? userId;
  String? userName;
  String? type;
  String? transactionType;
  String? currency;
  var amount;
  var balance;
  var walletBalance;
  String? datetime;
  int? orderId;
  String? createdAt;
  String? updatedAt;

  RewardsModel({
    this.id,
    this.userId,
    this.userName,
    this.type,
    this.transactionType,
    this.currency,
    this.amount,
    this.balance,
    this.walletBalance,
    this.datetime,
    this.orderId,
    this.createdAt,
    this.updatedAt,
  });

  factory RewardsModel.fromJson(Map<String, dynamic> json) {
    return RewardsModel(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      type: json['type'],
      transactionType: json['transaction_type'],
      currency: json['currency'],
      amount: json['amount'],
      balance: json['balance'],
      walletBalance: json['wallet_balance'],
      datetime: json['datetime'],
      orderId: json['ride_request_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['user_id'] = this.userId;
    data['user_name'] = this.userName;
    data['type'] = this.type;
    data['currency'] = this.currency;
    data['amount'] = this.amount;
    data['balance'] = this.balance;
    data['wallet_balance'] = this.walletBalance;
    data['datetime'] = this.datetime;
    data['ride_request_id'] = this.orderId;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

PageListModel pageListModelfromJson(String str) =>
    PageListModel.fromJson(json.decode(str));

String pageListModeltoJson(PageListModel data) => json.encode(data.toJson());

class PageListModel {
  PaginationModel? pagination;
  List<PageData>? data;

  PageListModel({
    this.pagination,
    this.data,
  });

  factory PageListModel.fromJson(Map<String, dynamic> json) => PageListModel(
        pagination: json["pagination"] == null
            ? null
            : PaginationModel.fromJson(json["pagination"]),
        data: json["data"] == null
            ? []
            : List<PageData>.from(
                json["data"]!.map((x) => PageData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "pagination": pagination?.toJson(),
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class PageData {
  int? id;
  String? title;
  String? description;
  String? slug;
  int? status;

  PageData({
    this.id,
    this.title,
    this.description,
    this.slug,
    this.status,
  });

  factory PageData.fromJson(Map<String, dynamic> json) => PageData(
        id: json["id"],
        title: json["title"],
        description: json["description"],
        status: json["status"],
        slug: json["slug"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "description": description,
        "status": status,
        "slug": slug,
      };
}

