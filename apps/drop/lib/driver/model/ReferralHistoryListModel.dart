import 'PaginationModel.dart';
import 'UserDetailModel.dart';

class ReferralHistoryListModel {
  List<UserData>? data;
  PaginationModel? pagination;

  ReferralHistoryListModel({this.data, this.pagination});

  factory ReferralHistoryListModel.fromJson(Map<String, dynamic> json) {
    return ReferralHistoryListModel(
      data: json['data'] != null
          ? (json['data'] as List).map((i) => UserData.fromJson(i)).toList()
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
