import '../manage_imports.dart';

CancleListResponse cancleListResponseFromJson(String str) => CancleListResponse.fromJson(json.decode(str));

String cancleListResponseToJson(CancleListResponse data) => json.encode(data.toJson());

class CancleListResponse {
  Pagination pagination;
  List<CancleData> data;

  CancleListResponse({
    required this.pagination,
    required this.data,
  });

  factory CancleListResponse.fromJson(Map<String, dynamic> json) => CancleListResponse(
        pagination: Pagination.fromJson(json["pagination"]),
        data: List<CancleData>.from(json["data"].map((x) => CancleData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "pagination": pagination.toJson(),
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class CancleData {
  int id;
  String title;
  String type;
  DateTime createdAt;

  CancleData({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
  });

  factory CancleData.fromJson(Map<String, dynamic> json) => CancleData(
        id: json["id"] ?? 0,
        title: json["title"] ?? "",
        type: json["type"] ?? "",
        createdAt: json["created_at"] != null ? DateTime.parse(json["created_at"]) : DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "type": type,
        "created_at": createdAt.toIso8601String(),
      };
}

class Pagination {
  int totalItems;
  int perPage;
  int currentPage;
  int totalPages;

  Pagination({
    required this.totalItems,
    required this.perPage,
    required this.currentPage,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        totalItems: json["total_items"],
        perPage: json["per_page"],
        currentPage: json["currentPage"],
        totalPages: json["totalPages"],
      );

  Map<String, dynamic> toJson() => {
        "total_items": totalItems,
        "per_page": perPage,
        "currentPage": currentPage,
        "totalPages": totalPages,
      };
}
