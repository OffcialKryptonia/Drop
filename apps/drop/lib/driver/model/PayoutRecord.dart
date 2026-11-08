import 'dart:convert';

PayoutRecord payoutRecordFromJson(String str) => PayoutRecord.fromJson(json.decode(str));

String payoutRecordToJson(PayoutRecord data) => json.encode(data.toJson());

class PayoutRecord {
  PayoutRecord({
    required this.totalPayoutCount,
    required this.pagination,
    required this.data,
    required this.totalCount,
    required this.totalPayout,
    required this.totalPendingPayoutCount,
    required this.totalPendingPayout,
  });

  int totalPayoutCount;
  Pagination pagination;
  List<PayoutRecordList> data;
  int totalCount;

  /// ✅ Money fields changed to double
  double totalPayout;
  int totalPendingPayoutCount;
  double totalPendingPayout;

  factory PayoutRecord.fromJson(Map<String, dynamic> json) => PayoutRecord(
        totalPayoutCount: json["total_payout_count"] ?? 0,
        pagination: Pagination.fromJson(json["pagination"]),
        data: List<PayoutRecordList>.from(
          json["data"].map((x) => PayoutRecordList.fromJson(x)),
        ),
        totalCount: json["total_count"] ?? 0,
        totalPayout: _toDouble(json["total_payout"]),
        totalPendingPayoutCount: json["total_pending_payout_count"] ?? 0,
        totalPendingPayout: _toDouble(json["total_pending_payout"]),
      );

  Map<String, dynamic> toJson() => {
        "total_payout_count": totalPayoutCount,
        "pagination": pagination.toJson(),
        "data": data.map((x) => x.toJson()).toList(),
        "total_count": totalCount,
        "total_payout": totalPayout,
        "total_pending_payout_count": totalPendingPayoutCount,
        "total_pending_payout": totalPendingPayout,
      };
}

class PayoutRecordList {
  PayoutRecordList({
    required this.receivedDocument,
    required this.totalCommission,
    required this.totalFare,
    required this.createdAt,
    required this.totalTrips,
    required this.updatedAt,
    required this.weekStartDate,
    required this.generatedAt,
    required this.driverTips,
    required this.payoutAmount,
    required this.weekEndDate,
    required this.status,
  });

  String? receivedDocument;

  /// Money fields changed to double
  double totalCommission;
  double totalFare;
  double driverTips;
  double payoutAmount;

  DateTime createdAt;
  int totalTrips;
  DateTime updatedAt;
  DateTime weekStartDate;
  DateTime generatedAt;
  DateTime weekEndDate;
  String status;

  factory PayoutRecordList.fromJson(Map<String, dynamic> json) => PayoutRecordList(
        receivedDocument: json["received_document"],
        totalCommission: _toDouble(json["total_commission"]),
        totalFare: _toDouble(json["total_fare"]),
        createdAt: DateTime.parse(json["created_at"]),
        totalTrips: json["total_trips"] ?? 0,
        updatedAt: DateTime.parse(json["updated_at"]),
        weekStartDate: DateTime.parse(json["week_start_date"]),
        generatedAt: DateTime.parse(json["generated_at"]),
        driverTips: _toDouble(json["driver_tips"]),
        payoutAmount: _toDouble(json["payout_amount"]),
        weekEndDate: DateTime.parse(json["week_end_date"]),
        status: json["status"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "received_document": receivedDocument,
        "total_commission": totalCommission,
        "total_fare": totalFare,
        "created_at": createdAt.toIso8601String(),
        "total_trips": totalTrips,
        "updated_at": updatedAt.toIso8601String(),
        "week_start_date": weekStartDate.toIso8601String(),
        "generated_at": generatedAt.toIso8601String(),
        "driver_tips": driverTips,
        "payout_amount": payoutAmount,
        "week_end_date": weekEndDate.toIso8601String(),
        "status": status,
      };
}

class Pagination {
  Pagination({
    required this.perPage,
    required this.totalPages,
    required this.currentPage,
    required this.totalItems,
  });

  int perPage;
  int totalPages;
  int currentPage;
  int totalItems;

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        perPage: json["per_page"] ?? 0,
        totalPages: json["totalPages"] ?? 0,
        currentPage: json["currentPage"] ?? 0,
        totalItems: json["total_items"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "per_page": perPage,
        "totalPages": totalPages,
        "currentPage": currentPage,
        "total_items": totalItems,
      };
}

/// Safe double parser
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
