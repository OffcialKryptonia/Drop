import '../manage_imports.dart';

class RideDetailModel {
  RiderModel? data;
  List<RideHistory>? rideHistory;
  DriverRatting? driverRatting;
  DriverRatting? riderRatting;
  ComplaintModel? complaintModel;
  Payment? payment;
  String? invoice_url;
  String? invoice_name;
  int? ride_has_bids;
  num? riderWalletBalance;
  num? coinEarnings;

  RideDetailModel({this.data, this.rideHistory, this.ride_has_bids, this.driverRatting, this.riderRatting, this.complaintModel, this.payment, this.invoice_url, this.invoice_name, this.riderWalletBalance, this.coinEarnings});

  factory RideDetailModel.fromJson(Map<String, dynamic> json) {
    return RideDetailModel(
      data: json['data'] != null ? RiderModel.fromJson(json['data']) : null,
      invoice_url: json['invoice_url'] != null ? json['invoice_url'] : null,
      ride_has_bids: json['ride_has_bids'] != null ? int.tryParse(json['ride_has_bids'].toString()) : null,
      invoice_name: json['invoice_name'] != null ? json['invoice_name'] : null,
      rideHistory: json['ride_history'] != null ? (json['ride_history'] as List).map((i) => RideHistory.fromJson(i)).toList() : null,
      driverRatting: json['driver_rating'] != null ? DriverRatting.fromJson(json['driver_rating']) : null,
      riderRatting: json['rider_rating'] != null ? DriverRatting.fromJson(json['rider_rating']) : null,
      complaintModel: json['complaint'] != null ? ComplaintModel.fromJson(json['complaint']) : null,
      payment: json['payment'] != null ? Payment.fromJson(json['payment']) : null,
      riderWalletBalance: json['rider_wallet_balance'],
      coinEarnings: json['coin_earnings'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    if (this.rideHistory != null) {
      data['ride_history'] = this.rideHistory!.map((v) => v.toJson()).toList();
    }
    if (this.driverRatting != null) {
      data['driver_rating'] = this.driverRatting!.toJson();
    }
    if (this.riderRatting != null) {
      data['rider_rating'] = this.riderRatting!.toJson();
    }
    if (this.complaintModel != null) {
      data['complaint'] = this.complaintModel!.toJson();
    }
    if (this.payment != null) {
      data['payment'] = this.payment!.toJson();
    }
    if (this.invoice_name != null) {
      data['invoice_name'] = this.invoice_name;
    }
    if (this.invoice_url != null) {
      data['invoice_url'] = this.invoice_url;
    }
    if (this.ride_has_bids != null) {
      data['ride_has_bids'] = this.ride_has_bids;
    }
    if (this.riderWalletBalance != null) {
      data['rider_wallet_balance'] = this.riderWalletBalance;
    }
    if (this.coinEarnings != null) {
      data['coinEarnings'] = this.coinEarnings;
    }
    return data;
  }
}
