class RideHistory {
  String? createdAt;
  String? datetime;
  String? historyMessage;
  String? historyType;
  int? id;
  int? rideRequestId;
  String? updatedAt;

  RideHistory({
    this.createdAt,
    this.datetime,
    this.historyMessage,
    this.historyType,
    this.id,
    this.rideRequestId,
    this.updatedAt,
  });

  factory RideHistory.fromJson(Map<String, dynamic> json) {
    return RideHistory(
      createdAt: json['created_at'],
      datetime: json['datetime'],
      historyMessage: json['history_message'],
      historyType: json['history_type'],
      id: json['id'],
      rideRequestId: json['ride_request_id'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['created_at'] = this.createdAt;
    data['datetime'] = this.datetime;
    data['history_message'] = this.historyMessage;
    data['history_type'] = this.historyType;
    data['id'] = this.id;
    data['ride_request_id'] = this.rideRequestId;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

